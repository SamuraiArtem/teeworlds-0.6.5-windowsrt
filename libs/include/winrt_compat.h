#ifndef WINRT_COMPAT_H
#define WINRT_COMPAT_H
#include <math.h>

#ifndef __STRICT_ANSI__
#define __STRICT_ANSI_hack 1
#endif

#if defined(__cplusplus) && !defined(sqrtf)
float sqrtf(float);
float sinf(float);
float cosf(float);
float powf(float, float);
float asinf(float);
float acosf(float);
float fabsf(float);
float floorf(float);
float ceilf(float);
float atan2f(float, float);
float tanf(float);
float logf(float);
float expf(float);
float roundf(float);
float fmodf(float, float);
#endif

#endif
