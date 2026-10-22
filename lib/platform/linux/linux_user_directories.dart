import 'dart:io';

import 'linux_commands.dart';

/// Profile-local XDG special folders, not copies of the host's personal files.
final class LinuxUserDirectories {
  static Future<void> prepare(String root, String profile) async {
    final result = await LinuxCommands.run('/usr/bin/python3', [
      '-c',
      helper,
      root,
      profile,
    ]);
    if (result.exitCode != 0) {
      throw FileSystemException(result.stderr.toString().trim(), profile);
    }
  }

  static const helper = r'''
import hashlib,os,pathlib,secrets,stat,sys
root,profile=map(pathlib.Path,sys.argv[1:])
flags=os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW
marker=b'# Atyaf user directories v1 '
limit=65536

def directory(parent,name):
    try: os.mkdir(name,0o700,dir_fd=parent)
    except FileExistsError: pass
    fd=os.open(name,flags,dir_fd=parent)
    info=os.fstat(fd)
    if info.st_uid!=os.getuid() or stat.S_IMODE(info.st_mode)&0o022:
        os.close(fd)
        raise ValueError('Unsafe user directory owner or permissions')
    return fd

def read(config):
    try: fd=os.open('user-dirs.dirs',os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=config)
    except FileNotFoundError: return None,None
    try:
        info=os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid!=os.getuid() or info.st_nlink!=1 or info.st_size>limit:
            raise ValueError('Unsafe user directory configuration')
        with os.fdopen(os.dup(fd),'rb') as stream: raw=stream.read(limit+1)
        if len(raw)>limit: raise ValueError('Oversized user directory configuration')
        return raw,(info.st_dev,info.st_ino,info.st_size,info.st_mtime_ns,info.st_ctime_ns)
    finally: os.close(fd)

def prepare():
    if profile.resolve(strict=True)!=root.resolve(strict=True)/'profiles'/profile.name:
        raise ValueError('User directories escaped the managed profile')
    base=os.open(profile,flags)
    config=data=folders=None
    try:
        info=os.fstat(base)
        if info.st_uid!=os.getuid() or stat.S_IMODE(info.st_mode)&0o022:
            raise ValueError('Unsafe managed profile')
        config=directory(base,'config')
        old,identity=read(config)
        if old is not None:
            header,sep,body=old.partition(b'\n')
            # Preserve every user-provided/edited file, including empty files.
            if not sep or header!=marker+hashlib.sha256(body).hexdigest().encode(): return
        data=directory(base,'data')
        folders=directory(data,'user-directories')
        lines=[]
        for key,name in [('DESKTOP','Desktop'),('DOWNLOAD','Downloads'),('TEMPLATES','Templates'),('PUBLICSHARE','Public'),('DOCUMENTS','Documents'),('MUSIC','Music'),('PICTURES','Pictures'),('VIDEOS','Videos')]:
            child=directory(folders,name); os.close(child)
            path=str(profile/'data'/'user-directories'/name)
            if any(c in path for c in '\n\r\x00'): raise ValueError('Invalid user directory path')
            for char in ['\\','"','$','`']: path=path.replace(char,'\\'+char)
            lines.append('XDG_'+key+'_DIR="'+path+'"\n')
        body=''.join(lines).encode()
        raw=marker+hashlib.sha256(body).hexdigest().encode()+b'\n'+body
        if raw==old: return
        name='.user-dirs-'+secrets.token_hex(12)
        fd=os.open(name,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=config)
        try:
            with os.fdopen(fd,'wb') as stream:
                stream.write(raw); stream.flush(); os.fsync(stream.fileno())
            if read(config)!=(old,identity): raise ValueError('User directory configuration changed concurrently')
            if old is None:
                os.link(name,'user-dirs.dirs',src_dir_fd=config,dst_dir_fd=config,follow_symlinks=False)
            else:
                os.replace(name,'user-dirs.dirs',src_dir_fd=config,dst_dir_fd=config)
        finally:
            try: os.unlink(name,dir_fd=config)
            except FileNotFoundError: pass
    finally:
        for fd in [folders,data,config,base]:
            if fd is not None: os.close(fd)
prepare()
''';
}
