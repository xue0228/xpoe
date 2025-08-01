// 1.5x faster. Uses 128-bit registers and searches 4 pixels at once.
#include <emmintrin.h>

#define _mm_cmpge_epu8(a, b) _mm_cmpeq_epi8(_mm_max_epu8(a, b), a)
#define _mm_cmple_epu8(a, b) _mm_cmpge_epu8(b, a)
#define _mm_cmpgt_epu8(a, b) _mm_xor_si128(_mm_cmple_epu8(a, b), _mm_set1_epi8(-1))
#define _mm_cmplt_epu8(a, b) _mm_cmpgt_epu8(b, a)

unsigned int * pixelsearch2x(unsigned int * start, unsigned int * end, unsigned char rh, unsigned char rl, unsigned char gh, unsigned char gl, unsigned char bh, unsigned char bl) {

    // Comparison mask for unsigned integers.
    __m128i vmask = _mm_set1_epi32(0xFFFFFFFF);

    // Reconstruct ARGB from individual color channels.
    unsigned int h = (0xFF << 24 | rh << 16 | gh << 8 | bh << 0);
    unsigned int l = (0x00 << 24 | rl << 16 | gl << 8 | bl << 0);

    // Create a vector of four copies of the target color.
    __m128i vh = _mm_set1_epi32(h);
    __m128i vl = _mm_set1_epi32(l);

    // Loop over start pointer with a step of four unsigned integers.
    while (start < end - 3) {

        // Load four unsigned integers from start into a vector.
        __m128i vstart = _mm_loadu_si128((__m128i *) start);

        // Compare vstart <= vh and vstart >= vl. Note these are macros.
        __m128i v2 = _mm_cmple_epu8(vstart, vh);
        __m128i v3 = _mm_cmpge_epu8(vstart, vl);
        __m128i v1234 = _mm_and_si128(v2, v3);

        // Check if any of the four unsigned integers matched.
        __m128i vcmp = _mm_cmpeq_epi32(v1234, vmask);

        // Create a mask from each byte (using the most significant bit) in vcmp.
        int mask = _mm_movemask_epi8(vcmp);

        // If the mask is nonzero, there is at least one match.
        if (mask != 0)
            break;

        // Increment start by four unsigned integers.
        start += 4;
    }

    // Clean up any remaining elements.
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