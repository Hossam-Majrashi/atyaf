#!/usr/bin/env python3
"""Discover and normalize desktop icons using the existing GTK3 runtime.

No candidate executable is started. Installed icons, managed Electron resources
and fallback images are decoded, not merely accepted by filename extension.
"""
import base64
import configparser
import ctypes
import json
import os
from pathlib import Path
import shlex
import shutil
import sys
import tempfile

pixbuf = ctypes.CDLL('libgdk_pixbuf-2.0.so.0')
gobject = ctypes.CDLL('libgobject-2.0.so.0')
glib = ctypes.CDLL('libglib-2.0.so.0')
pixbuf.gdk_pixbuf_get_file_info.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int)]
pixbuf.gdk_pixbuf_get_file_info.restype = ctypes.c_void_p
pixbuf.gdk_pixbuf_new_from_file_at_scale.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.POINTER(ctypes.c_void_p)]
pixbuf.gdk_pixbuf_new_from_file_at_scale.restype = ctypes.c_void_p
pixbuf.gdk_pixbuf_savev.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]
pixbuf.gdk_pixbuf_savev.restype = ctypes.c_int
gobject.g_object_unref.argtypes = [ctypes.c_void_p]
glib.g_error_free.argtypes = [ctypes.c_void_p]


def load(path, size=64):
    try:
        path = Path(path)
        if not path.is_file() or not 0 < path.stat().st_size <= 16 * 1024 * 1024:
            return None
        encoded = os.fsencode(path)
        width, height = ctypes.c_int(), ctypes.c_int()
        if not pixbuf.gdk_pixbuf_get_file_info(encoded, ctypes.byref(width), ctypes.byref(height)):
            return None
        if not 0 < width.value <= 8192 or not 0 < height.value <= 8192:
            return None
        error = ctypes.c_void_p()
        image = pixbuf.gdk_pixbuf_new_from_file_at_scale(encoded, size, size, True, ctypes.byref(error))
        if error.value:
            glib.g_error_free(error)
        return image
    except (OSError, ValueError):
        return None


def valid(path):
    image = load(path)
    if image:
        gobject.g_object_unref(image)
        return str(Path(path).absolute())
    return None


def image_extensions():
    class GSList(ctypes.Structure):
        pass
    GSList._fields_ = [('data', ctypes.c_void_p), ('next', ctypes.POINTER(GSList))]
    pixbuf.gdk_pixbuf_get_formats.restype = ctypes.POINTER(GSList)
    pixbuf.gdk_pixbuf_format_is_disabled.argtypes = [ctypes.c_void_p]
    pixbuf.gdk_pixbuf_format_is_disabled.restype = ctypes.c_int
    pixbuf.gdk_pixbuf_format_get_extensions.argtypes = [ctypes.c_void_p]
    pixbuf.gdk_pixbuf_format_get_extensions.restype = ctypes.POINTER(ctypes.c_char_p)
    glib.g_strfreev.argtypes = [ctypes.POINTER(ctypes.c_char_p)]
    glib.g_slist_free.argtypes = [ctypes.POINTER(GSList)]
    head = pixbuf.gdk_pixbuf_get_formats()
    item = head
    result = set()
    try:
        while item:
            if not pixbuf.gdk_pixbuf_format_is_disabled(item.contents.data):
                extensions = pixbuf.gdk_pixbuf_format_get_extensions(item.contents.data)
                try:
                    index = 0
                    while extensions and extensions[index]:
                        extension = extensions[index].decode('ascii').lower()
                        if extension.isalnum() and len(extension) <= 16:
                            result.add(extension)
                        index += 1
                finally:
                    if extensions: glib.g_strfreev(extensions)
            item = item.contents.next
    finally:
        if head: glib.g_slist_free(head)
    return sorted(result)


IMAGE_EXTENSIONS = {'.' + extension for extension in image_extensions()}


def project_root(request):
    root = Path(request['root'])
    if not root.is_absolute() or not root.is_dir():
        raise ValueError('Project root must be an existing absolute directory')
    return root.resolve()


def scan_images(request):
    root = project_root(request)
    images = []
    count = 0

    def failed(error):
        raise error  # Never silently omit unreadable parts of the project.

    for directory, folders, files in os.walk(root, followlinks=False, onerror=failed):
        folders[:] = sorted(folder for folder in folders if not (Path(directory) / folder).is_symlink())
        count += len(folders) + len(files)
        if count > 100000:
            raise ValueError('Project scan exceeds 100000 entries; choose a smaller image folder')
        for name in sorted(files):
            path = Path(directory) / name
            if path.suffix.lower() not in IMAGE_EXTENSIONS and name != '.DirIcon':
                continue
            if path.resolve().is_relative_to(root) and path.is_file():
                images.append(str(path.relative_to(root)))
    return sorted(images)


def previews(request):
    root = project_root(request)
    size = request.get('size', 96)
    paths = request['paths']
    if size not in (96, 512) or len(paths) > 40:
        raise ValueError('Invalid preview request')
    result = []
    with tempfile.TemporaryDirectory(prefix='atyaf-preview-') as temporary:
        for relative in paths:
            path = root / relative
            if Path(relative).is_absolute() or '..' in Path(relative).parts or not path.resolve().is_relative_to(root):
                raise ValueError('Image path escapes project')
            image = load(path, size)
            if not image:
                result.append(None)
                continue
            try:
                output = Path(temporary) / 'preview.png'
                error = ctypes.c_void_p()
                saved = pixbuf.gdk_pixbuf_savev(image, os.fsencode(output), b'png', None, None, ctypes.byref(error))
                if error.value:
                    glib.g_error_free(error)
                if not saved or output.stat().st_size > 2 * 1024 * 1024:
                    result.append(None)
                else:
                    result.append(base64.b64encode(output.read_bytes()).decode('ascii'))
            finally:
                gobject.g_object_unref(image)
    return result


def local_icons(request):
    executable = Path(request['executable'])
    root = Path(request['portableRoot']).resolve() if request.get('portableRoot') else None
    for base in dict.fromkeys([executable.parent, root] if root else [executable.parent]):
        for relative in ['resources/app/resources/linux', 'resources/linux', '']:
            for name in dict.fromkeys([executable.name, 'code', 'icon']):
                for extension in ['.png', '.svg', '.xpm']:
                    candidate = base / relative / (name + extension)
                    if root and not candidate.resolve().is_relative_to(root):
                        continue
                    result = valid(candidate)
                    if result:
                        yield result
        candidate = base / '.DirIcon'
        if not root or candidate.resolve().is_relative_to(root):
            result = valid(candidate)
            if result:
                yield result


def resolve_icon(name, entry, request):
    if not name or any(c in name for c in '\n\r\x00'):
        return None
    if os.path.isabs(name):
        return valid(name)
    if '/' in name:
        return valid(entry.parent / name)
    # A portable desktop file may refer to an icon beside itself.
    result = valid(entry.parent / name)
    if result:
        return result
    bases = [Path(request['dataHome']) / 'icons', Path(request['home']) / '.icons']
    bases += [Path(base) / 'icons' for base in request['dataDirs']]
    stem = Path(name).stem if Path(name).suffix in ['.png', '.svg', '.xpm'] else name
    for base in bases:
        for theme in sorted(base.glob('*')):
            for extension in ['.png', '.svg', '.xpm']:
                matches = sorted(theme.glob('*/apps/' + stem + extension),
                                 key=lambda path: ('512' not in str(path), 'scalable' not in str(path), str(path)))
                for candidate in matches:
                    result = valid(candidate)
                    if result:
                        return result
    for base in request['dataDirs']:
        for extension in ['.png', '.svg', '.xpm']:
            result = valid(Path(base) / 'pixmaps' / (stem + extension))
            if result:
                return result
    return None


def discover(request):
    # Prefer the actual imported application's logo, including VS Code forks
    # such as Antigravity whose Linux logo is called code.png.
    for icon in local_icons(request):
        return icon
    entries = []
    if request.get('portableRoot'):
        entries += sorted(Path(request['portableRoot']).glob('*.desktop'))
        entries += sorted(Path(request['executable']).parent.glob('*.desktop'))
    for directory in [request['dataHome']] + request['dataDirs']:
        entries += sorted((Path(directory) / 'applications').glob('*.desktop'))
    for entry in entries:
        try:
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            parser.read(entry, encoding='utf-8')
            section = parser['Desktop Entry']
            if section.get('Type') != 'Application':
                continue
            command = shlex.split(section.get('Exec', ''))
            target = shutil.which(command[0], path=request['path']) if command else None
            matches = target and os.path.realpath(target) == os.path.realpath(request['executable'])
            if not matches and not (request.get('wmClass') and section.get('StartupWMClass') == request['wmClass']):
                continue
            icon = resolve_icon(section.get('Icon', ''), entry, request)
            if icon:
                return icon
        except (OSError, ValueError, KeyError, configparser.Error):
            continue
    return None


def install(destination, sources):
    for source in sources:
        image = load(source, 512)
        if not image:
            continue
        temporary = None
        try:
            descriptor, temporary = tempfile.mkstemp(prefix='.atyaf-icon-', dir=Path(destination).parent)
            os.close(descriptor)
            error = ctypes.c_void_p()
            saved = pixbuf.gdk_pixbuf_savev(image, os.fsencode(temporary), b'png', None, None, ctypes.byref(error))
            if error.value:
                glib.g_error_free(error)
            if not saved:
                raise ValueError('Unable to encode desktop icon')
            os.chmod(temporary, 0o644)
            os.replace(temporary, destination)
            return
        finally:
            gobject.g_object_unref(image)
            if temporary and os.path.exists(temporary):
                os.unlink(temporary)
    raise ValueError('No readable desktop icon, including fallback')


if __name__ == '__main__':
    if sys.argv[1] == 'find':
        icon = discover(json.loads(sys.argv[2]))
        if icon:
            print(icon)
    elif sys.argv[1] == 'install':
        install(sys.argv[2], sys.argv[3:])
    elif sys.argv[1] == 'formats':
        print(json.dumps(image_extensions()))
    elif sys.argv[1] == 'scan':
        print(json.dumps(scan_images(json.loads(sys.argv[2])), ensure_ascii=False))
    elif sys.argv[1] == 'previews':
        print(json.dumps(previews(json.loads(sys.argv[2]))))
    else:
        raise ValueError('Unknown icon operation')
