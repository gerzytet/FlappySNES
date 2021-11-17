import sys

def encode_color(r, g, b):
    r = r >> 3
    g = g >> 3
    b = b >> 3
    result = (b << 10) | (g << 5) | r
    return result

blank = '''
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
'''.strip()

center = blank.replace('0', '2')

side = '''
00011222
00011222
00011222
00011222
00011222
00011222
00011222
00011222
'''.strip()

corner = '''
00011222
00011222
00011222
00011222
00011222
00011122
00011111
00001111
'''.strip()

bottom = '''
22222222
22222222
22222222
22222222
22222222
22222222
11111111
11111111
'''.strip()

def quarters(s):
    lines = s.split('\n')
    assert len(lines) % 2 == 0 and len(lines[0]) % 2 == 0 and len(lines) == len(lines[0])
    ans = [None] * 4
    mid = len(lines) // 2
    fuse = lambda lines: '\n'.join(lines)
    left  = lambda lines: [line[:mid] for line in lines]
    right = lambda lines: [line[mid:] for line in lines]
    ans[0] = fuse(left(lines[:mid]))
    ans[1] = fuse(right(lines[:mid]))
    ans[2] = fuse(left(lines[mid:]))
    ans[3] = fuse(right(lines[mid:]))
    return ans
    
bird = '''
0000001111110000
0000114441441000
0001443314444100
0111133314441410
1444413314441410
1444441331444410
1344431333111111
0133313331222222
0011155512111111
0015555551222221
0001155555111110
0000011111000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
'''.strip()

pal = [
    (68, 212, 219), 
    (0x00, 0x94, 0x00),
    (0x00, 0xFF, 0x00),
    (0x92, 0x91, 0x00)
]

pal_bird = [
    (0, 0, 0),
    (57, 53, 54),
    (250, 79, 62),
    (254, 240, 30),
    (254, 255, 249),
    (247, 174, 20)
]

bird_split = quarters(bird)

#returns list of bytes
#8x8
def encode_char2(s):
    bpp = 2
    rows = s.split('\n')
    nums = [[int(c) for c in row] for row in rows]
    result = []
    for row in nums:
        for plane in range(bpp):
            byte = 0
            #index = bpp - plane - 1
            index = plane
            for i, c in enumerate(row):
                byte <<= 1
                byte |= (c & (1 << index)) >> index
            result.append(byte)
    return result

def encode_char4(s):
    bpp = 4
    rows = s.split('\n')
    nums = [[int(c) for c in row] for row in rows]
    result = []
    for plane_offset in [0, 2]:
        for row in nums:
            for plane in range(plane_offset, plane_offset+2):
                byte = 0
                #index = bpp - plane - 1
                index = plane
                for i, c in enumerate(row):
                    byte <<= 1
                    byte |= (c & (1 << index)) >> index
                result.append(byte)
    return result

def write_bytes(file_name, data):
    bytes = []
    for i in data:
        bytes.append(i.to_bytes(1, 'big'))
    bytes = b''.join(bytes)
    with open(file_name, 'wb') as file:
        file.write(bytes)

def encode_pallete(pal):
    pal = list(map(lambda x: encode_color(*x), pal))
    bytes = []
    for p in pal:
        bytes.append(p.to_bytes(2, 'little'))
    return b''.join(bytes)



blank_b2  = encode_char2(blank)
center_b = encode_char2(center)
side_b   = encode_char2(side)
corner_b = encode_char2(corner)
bottom_b = encode_char2(bottom)

tiles = blank_b2 * 2 + (side_b + center_b) + (side_b   + center_b) + (10 * blank_b2) +\
        blank_b2 * 2 + (side_b + center_b) + (corner_b + bottom_b)

write_bytes('pipes.bin', tiles)

bird_b = list(map(lambda s: encode_char4(s), bird_split))

blank_b4 = encode_char4(blank)
tiles = bird_b[0] + bird_b[1] + blank_b4 * 14 +\
        bird_b[2] + bird_b[3]

write_bytes('bird.bin', tiles)

b = encode_pallete(pal)
write_bytes('pipes.pal', b)

b = encode_pallete(pal_bird)
write_bytes('bird.pal', b)
