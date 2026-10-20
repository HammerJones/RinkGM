"""Rewrites a .vox keeping only its surface voxels (6-neighbour exposed),
copying the palette and materials and dropping editor-only chunks
(cameras, layers, notes). A solid 2M-voxel model becomes a 120k one with
the same look; the game only draws faces.

    python3 tools/propgen/hollow.py in.vox out.vox
    python3 tools/propgen/hollow.py a.vox b.vox c.vox   # in place
"""
import sys, struct, numpy as np
def hollow(src, dst):
    d=open(src,'rb').read(); pos=8; out=[]; size=None
    chunks=[]
    while pos+12<=len(d):
        cid=d[pos:pos+4]; n,m=struct.unpack('<II',d[pos+4:pos+12]); body=d[pos+12:pos+12+n]
        chunks.append((cid,body,m)); pos+=12+n
    for i,(cid,body,m) in enumerate(chunks):
        if cid==b'SIZE': size=struct.unpack('<III',body[:12])
        if cid==b'XYZI':
            cnt=struct.unpack('<I',body[:4])[0]; v=np.frombuffer(body[4:4+cnt*4],dtype=np.uint8).reshape(-1,4)
            g=np.zeros((size[0]+2,size[1]+2,size[2]+2),dtype=bool); g[v[:,0]+1,v[:,1]+1,v[:,2]+1]=True
            inner=g[:-2,1:-1,1:-1]&g[2:,1:-1,1:-1]&g[1:-1,:-2,1:-1]&g[1:-1,2:,1:-1]&g[1:-1,1:-1,:-2]&g[1:-1,1:-1,2:]
            keep=~inner[v[:,0],v[:,1],v[:,2]]
            v2=v[keep]
            chunks[i]=(cid, struct.pack('<I',len(v2))+v2.tobytes(), m)
            print(src.rsplit('/',1)[-1], "voxels", cnt, "->", len(v2))
    # drop camera/render/layer/note chunks: not needed by the game
    keep_ids={b'SIZE',b'XYZI',b'RGBA',b'MATL',b'nTRN',b'nGRP',b'nSHP',b'IMAP'}
    body=b''.join(cid+struct.pack('<II',len(b),0)+b for cid,b,m in chunks if cid in keep_ids)
    open(dst,'wb').write(b'VOX '+struct.pack('<I',150)+b'MAIN'+struct.pack('<II',0,len(body))+body)
if __name__ == "__main__":
    # hollow.py in.vox out.vox   (or several inputs, rewritten in place)
    args = sys.argv[1:]
    if len(args) == 2 and not args[1].endswith(".vox") is False and args[0] != args[1]:
        hollow(args[0], args[1])
    else:
        for a in args:
            hollow(a, a)
