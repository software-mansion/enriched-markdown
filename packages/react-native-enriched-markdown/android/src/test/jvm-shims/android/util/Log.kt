package android.util

/** Logging-only shim for running the production JNI parser on a local JVM. */
object Log {
  fun e(
    tag: String,
    message: String,
    error: Throwable,
  ): Int {
    System.err.println("$tag: $message")
    error.printStackTrace()
    return 0
  }

  fun w(
    tag: String,
    message: String,
  ): Int {
    System.err.println("$tag: $message")
    return 0
  }
}
