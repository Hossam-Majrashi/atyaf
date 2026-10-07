import 'dart:convert';

import 'linux_commands.dart';

/// Supply the host's public window-button preference as a profile-local schema
/// default. Existing backend values win; no dconf database or user settings copy.
final class LinuxWindowPreferences {
  static Future<bool> prepare(
    String root,
    String profile,
    Map<String, String> host,
  ) async {
    try {
      final environment = {
        for (final key in [
          'HOME',
          'XDG_CONFIG_HOME',
          'XDG_DATA_DIRS',
          'XDG_CURRENT_DESKTOP',
          'XDG_RUNTIME_DIR',
          'DBUS_SESSION_BUS_ADDRESS',
          'LANG',
          'GSETTINGS_BACKEND',
        ])
          if (host.containsKey(key)) key: host[key]!,
      };
      final result = await LinuxCommands.run('/usr/bin/python3', [
        '-c',
        helper,
        root,
        profile,
        jsonEncode(environment),
      ]).timeout(const Duration(seconds: 5));
      return result.exitCode == 0 &&
          jsonDecode(result.stdout.toString()) == true;
    } catch (_) {
      // Cosmetic integration is optional, not a prerequisite for launching.
      return false;
    }
  }

  static const helper = r'''
import ast,configparser,copy,hashlib,json,os,pathlib,re,signal,stat,subprocess,sys,tempfile,xml.etree.ElementTree as ET
# Bound even optional filesystem/tool integration; never strand launch startup.
def timeout(signum,frame): raise TimeoutError('Window preference timeout')
signal.signal(signal.SIGALRM,timeout); signal.alarm(4)
SCHEMA='org.gnome.desktop.wm.preferences'
KEY='button-layout'
LIMIT=1024*1024
FLAGS=os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW
root,profile,environment=sys.argv[1:]
environment=json.loads(environment)
def regular(fd):
    info=os.fstat(fd)
    return stat.S_ISREG(info.st_mode) and info.st_uid==os.getuid() and info.st_size<=LIMIT

def read_at(fd,name):
    child=os.open(name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=fd)
    try:
        if not regular(child): raise ValueError('Unsafe preference file')
        with os.fdopen(os.dup(child),'rb') as stream: return stream.read(LIMIT+1)
    finally: os.close(child)

def explicit_gtk(config):
    for version in ['gtk-3.0','gtk-4.0']:
        try: fd=os.open(version,FLAGS,dir_fd=config)
        except FileNotFoundError: continue
        try:
            try: raw=read_at(fd,'settings.ini')
            except FileNotFoundError: continue
            parser=configparser.ConfigParser(interpolation=None,strict=False)
            parser.read_string(raw.decode('utf-8'))
            if parser.has_option('Settings','gtk-decoration-layout'): return True
        finally: os.close(fd)
    return False

def public_xml(path):
    fd=os.open(path,os.O_RDONLY|os.O_NONBLOCK)
    with os.fdopen(fd,'rb') as stream:
        info=os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size>LIMIT: raise ValueError('Unsafe schema size')
        raw=stream.read(LIMIT+1)
    if len(raw)>LIMIT: raise ValueError('Oversized schema')
    return ET.fromstring(raw)

def prepare():
    canonical=pathlib.Path(profile).resolve(strict=True)
    if canonical!=pathlib.Path(root).resolve(strict=True)/'profiles'/pathlib.Path(profile).name:
        return False
    base=os.open(profile,FLAGS)
    try:
        if os.fstat(base).st_uid!=os.getuid(): return False
        config=os.open('config',FLAGS,dir_fd=base)
        try:
            if explicit_gtk(config): return False
        finally: os.close(config)
        queried=subprocess.run(['/usr/bin/gsettings','get',SCHEMA,KEY],env=environment,capture_output=True,text=True,timeout=2)
        if queried.returncode: return False
        layout=ast.literal_eval(queried.stdout.strip())
        if not isinstance(layout,str) or len(layout)>128 or not re.fullmatch(r'[a-z,]*:[a-z,]*',layout): return False
        if set(layout.replace(':',',').split(','))-{'','menu','appmenu','icon','minimize','maximize','close','spacer'}: return False
        schema_root=None
        for directory in (environment.get('XDG_DATA_DIRS') or '/usr/local/share:/usr/share').split(':'):
            if not os.path.isabs(directory): continue
            source=pathlib.Path(directory)/'glib-2.0/schemas'
            candidate=source/(SCHEMA+'.gschema.xml')
            if candidate.is_file():
                schema_root=public_xml(candidate)
                break
        if schema_root is None: return False
        schema=next((n for n in schema_root.findall('schema') if n.get('id')==SCHEMA),None)
        if schema is None or schema.get('extends'): return False
        schema=copy.deepcopy(schema)
        # Compiled distro overrides can differ from the shipped XML defaults.
        # Query a memory backend: public defaults only, never user values.
        defaults=subprocess.run(['/usr/bin/gsettings','list-recursively',SCHEMA],env={**environment,'GSETTINGS_BACKEND':'memory'},capture_output=True,text=True,timeout=2)
        if defaults.returncode or len(defaults.stdout.encode('utf-8'))>LIMIT: return False
        values={}
        for line in defaults.stdout.splitlines():
            namespace,name,value=line.split(None,2)
            if namespace!=SCHEMA: return False
            values[name]=value
        if set(values)!={key.get('name') for key in schema.findall('key')}: return False
        for key in schema.findall('key'):
            key.find('default').text=values[key.get('name')]
        default=schema.find("key[@name='button-layout']/default")
        if default is None: return False
        default.text=repr(layout)
        output=ET.Element('schemalist',schema_root.attrib)
        required={key.get(kind) for key in schema.findall('key') for kind in ['enum','flags'] if key.get(kind)}
        # Enum declarations must precede keys. All other defaults remain intact.
        for node in list(schema_root)+list(public_xml(source/'org.gnome.desktop.enums.xml')):
            if node.tag in ('enum','flags') and node.get('id') in required:
                output.append(copy.deepcopy(node)); required.remove(node.get('id'))
        if required: return False
        output.append(schema)
        xml=ET.tostring(output,encoding='utf-8',xml_declaration=True)
        fingerprint=hashlib.sha256(xml).hexdigest().encode('ascii')
        try: os.mkdir('window-controls',0o700,dir_fd=base)
        except FileExistsError: pass
        cache=os.open('window-controls',FLAGS,dir_fd=base)
        try:
            info=os.fstat(cache)
            if info.st_uid!=os.getuid() or stat.S_IMODE(info.st_mode)!=0o700: return False
            try:
                cached=read_at(cache,'gschemas.compiled')
                if cached.startswith(b'GVariant') and read_at(cache,'fingerprint')==fingerprint+b'\n'+hashlib.sha256(cached).hexdigest().encode('ascii'):
                    return True
            except FileNotFoundError: pass
            # Compile in a private scratch directory; publish complete files only.
            pinned='/proc/self/fd/'+str(cache)
            with tempfile.TemporaryDirectory(prefix='compile-',dir=pinned) as scratch:
                pathlib.Path(scratch,'desktop.gschema.xml').write_bytes(xml)
                compiled=subprocess.run(['/usr/bin/glib-compile-schemas','--strict',scratch],capture_output=True,timeout=2,pass_fds=(cache,))
                if compiled.returncode: return False
                compiled_file=pathlib.Path(scratch,'gschemas.compiled')
                if compiled_file.stat().st_size>LIMIT: return False
                os.chmod(compiled_file,0o600)
                with compiled_file.open('rb') as stream: os.fsync(stream.fileno())
                os.replace(compiled_file,'gschemas.compiled',dst_dir_fd=cache)
                marker=pathlib.Path(scratch,'fingerprint')
                marker.write_bytes(fingerprint+b'\n'+hashlib.sha256(pathlib.Path(pinned,'gschemas.compiled').read_bytes()).hexdigest().encode('ascii')); os.chmod(marker,0o600)
                os.replace(marker,'fingerprint',dst_dir_fd=cache)
                os.fsync(cache)
            return True
        finally: os.close(cache)
    finally: os.close(base)
try: ready=prepare()
except (OSError,ValueError,ET.ParseError,configparser.Error,subprocess.SubprocessError,SyntaxError): ready=False
print(json.dumps(ready))
''';
}
