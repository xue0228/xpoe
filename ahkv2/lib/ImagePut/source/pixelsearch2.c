// 0.55x slower. Searches for a range of pixels.
unsigned int * pixelsearch2(unsigned int * start, unsigned int * end, unsigned char rh, unsigned char rl, unsigned char gh, unsigned char gl, unsigned char bh, unsigned char bl) {
    unsigned char r, g, b;
    while (start < end) {
        r = *((unsigned char *) start + 2);
        g = *((unsigned char *) start + 1);
        b = *((unsigned char *) start + 0);
        if (rh >= r && r >= rl && gh >= g && g >= gl && bh >= b && b >= bl)
            return start;
        start++;
    }
    return start; // start == end if no match.
}