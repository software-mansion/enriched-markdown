#pragma once

#include <stdarg.h>
#include <stdio.h>

#define ANDROID_LOG_INFO 4
#define ANDROID_LOG_ERROR 6

// The JNI adapter only requires Android's logging API. Parser behavior remains
// production code; route its diagnostics to stderr on the local test JVM.
static inline int __android_log_print(int priority, const char *tag, const char *format, ...) {
  (void)priority;
  fprintf(stderr, "%s: ", tag);
  va_list arguments;
  va_start(arguments, format);
  int result = vfprintf(stderr, format, arguments);
  va_end(arguments);
  fputc('\n', stderr);
  return result;
}
