import xml.etree.ElementTree as ET, os, sys
src = sys.argv[1]; out = sys.argv[2]
tree = ET.parse(src)
root = tree.getroot()
def name_of(item):
    for p in item.find('Properties'):
        if p.get('name') == 'Name': return p.text
    return item.get('class')
def walk(item, path):
    cls = item.get('class'); nm = name_of(item)
    p = path + [nm]
    props = item.find('Properties')
    srcnode = None
    for c in props:
        if c.get('name') == 'Source': srcnode = c
    if srcnode is not None:
        ext = {'Script':'.server.lua','LocalScript':'.client.lua','ModuleScript':'.lua'}.get(cls,'.lua')
        fp = os.path.join(out, *p[:-1], nm + ext)
        os.makedirs(os.path.dirname(fp), exist_ok=True)
        open(fp,'w').write(srcnode.text or '')
        print(cls, '/'.join(p), len((srcnode.text or '').splitlines()))
    else:
        print('  ', cls, '/'.join(p))
    for ch in item.findall('Item'):
        walk(ch, p)
for it in root.findall('Item'):
    walk(it, [])
