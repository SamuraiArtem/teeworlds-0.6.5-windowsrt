#ifndef MINGW_GLU_COMPAT_H
#define MINGW_GLU_COMPAT_H

#include <GL/gl.h>

#ifdef __cplusplus
extern "C" {
#endif

void gluBuild2DMipmaps(GLenum target, GLint components, GLint width, GLint height,
                       GLenum format, GLenum type, const void *pixels);

#ifdef __cplusplus
}
#endif

#endif