#include "glu_compat.h"
#include <stdlib.h>
#include <string.h>

#ifndef GL_UNSIGNED_SHORT_5_6_5
#define GL_UNSIGNED_SHORT_5_6_5 0x8363
#endif
#ifndef GL_UNSIGNED_SHORT_5_5_5_1
#define GL_UNSIGNED_SHORT_5_5_5_1 0x8034
#endif

typedef unsigned char u8;
typedef unsigned short u16;

static void *g_tmp = NULL;
static size_t g_tmp_size = 0;

static void *g_tmp_get(size_t n)
{
	if(n > g_tmp_size)
	{
		free(g_tmp);
		g_tmp = malloc(n);
		g_tmp_size = n;
	}
	return g_tmp;
}

static int glu_to_rgba(u8 *out, const void *src, int w, GLenum format, GLenum type)
{
	const u8 *p = (const u8 *)src;

	switch(type)
	{
	case GL_UNSIGNED_BYTE:
		if(format == GL_RGBA) { memcpy(out, p, (size_t)w*4); return 1; }
		for(int i = 0; i < w; i++)
		{
			u8 r, g, b, a = 255;
			switch(format)
			{
			case GL_RGB: r=p[0]; g=p[1]; b=p[2]; p+=3; break;
			case GL_LUMINANCE: r=g=b=p[0]; p+=1; break;
			case GL_LUMINANCE_ALPHA: r=g=b=p[0]; a=p[1]; p+=2; break;
			case GL_ALPHA: r=g=b=0; a=p[0]; p+=1; break;
			default: return 0;
			}
			out[0]=r; out[1]=g; out[2]=b; out[3]=a; out+=4;
		}
		return 1;
	case GL_UNSIGNED_SHORT_5_6_5:
		if(format != GL_RGB) return 0;
		for(int i = 0; i < w; i++)
		{
			u16 v = ((const u16 *)src)[i];
			u8 r=(u8)((v>>11)&31), g=(u8)((v>>5)&63), b=(u8)(v&31);
			out[0]=(r<<3)|(r>>2); out[1]=(g<<2)|(g>>4); out[2]=(b<<3)|(b>>2); out[3]=255; out+=4;
		}
		return 1;
	case GL_UNSIGNED_SHORT_5_5_5_1:
		if(format != GL_RGBA && format != GL_RGB) return 0;
		for(int i = 0; i < w; i++)
		{
			u16 v = ((const u16 *)src)[i];
			u8 r=(u8)((v>>11)&31), g=(u8)((v>>6)&31), b=(u8)((v>>1)&31);
			out[0]=(r<<3)|(r>>2); out[1]=(g<<3)|(g>>2); out[2]=(b<<3)|(b>>2); out[3]=(v&1)?255:0; out+=4;
		}
		return 1;
	default:
		return 0;
	}
}

static void glu_scale_nearest(u8 *dst, int dw, int dh, const u8 *src, int sw, int sh, int ncomp)
{
	for(int y = 0; y < dh; y++)
	{
		const int sy = (y*sh)/dh;
		const u8 *srow = src + (size_t)sy*sw*ncomp;
		u8 *drow = dst + (size_t)y*dw*ncomp;
		for(int x = 0; x < dw; x++)
		{
			const int sx = (x*sw)/dw;
			const u8 *sp = srow + (size_t)sx*ncomp;
			u8 *dp = drow + (size_t)x*ncomp;
			for(int c = 0; c < ncomp; c++) dp[c] = sp[c];
		}
	}
}

static void glu_downscale2x(u8 *dst, int dw, int dh, const u8 *src, int sw)
{
	for(int y = 0; y < dh; y++)
		for(int x = 0; x < dw; x++)
		{
			const u8 *s = src + ((size_t)(y*2)*sw + x*2)*4;
			for(int c = 0; c < 4; c++)
			{
				int v = s[c] + s[4+c] + s[(size_t)sw*4+c] + s[(size_t)sw*4+4+c];
				dst[((size_t)y*dw + x)*4 + c] = (u8)((v + 2) >> 2);
			}
		}
}

void gluBuild2DMipmaps(GLenum target, GLint components, GLint width, GLint height,
                       GLenum format, GLenum type, const void *pixels)
{
	int maxsize = 0;
	int pw, ph, w, h, levels, level;
	size_t need;
	u8 *base, *prev, *cur;

	if(target != GL_TEXTURE_2D || width <= 0 || height <= 0 || !pixels)
		return;

	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxsize);
	if(maxsize <= 0) maxsize = 2048;

	pw = 1; while(pw < width && pw < maxsize) pw <<= 1;
	ph = 1; while(ph < height && ph < maxsize) ph <<= 1;
	if(pw > maxsize) pw = maxsize;
	if(ph > maxsize) ph = maxsize;

	levels = 0;
	w = pw; h = ph;
	while(1) { levels++; if(w == 1 && h == 1) break; if(w>1) w>>=1; if(h>1) h>>=1; }

	need = (size_t)pw*ph*4;
	w = pw; h = ph;
	for(level = 1; level < levels; level++)
	{
		w = w>1?w/2:1; h = h>1?h/2:1;
		need += (size_t)w*h*4;
	}

	base = (u8 *)g_tmp_get(need + (size_t)pw*ph*4);
	if(!base) return;

	{
		u8 *conv = base + need;
		if(!glu_to_rgba(conv, pixels, width, format, type))
			return;
		glu_scale_nearest(base, pw, ph, conv, width, height, 4);
	}

	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glTexImage2D(target, 0, components, pw, ph, 0, GL_RGBA, GL_UNSIGNED_BYTE, base);

	prev = base;
	cur = base + (size_t)pw*ph*4;
	w = pw; h = ph;
	for(level = 1; level < levels; level++)
	{
		int nw = w>1?w/2:1, nh = h>1?h/2:1;
		glu_downscale2x(cur, nw, nh, prev, w);
		glTexImage2D(target, level, components, nw, nh, 0, GL_RGBA, GL_UNSIGNED_BYTE, cur);
		prev = cur;
		cur += (size_t)nw*nh*4;
		w = nw; h = nh;
	}

	glGetError();
}