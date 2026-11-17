#!/bin/sh
# Run from app/. JDK 21 fixes lint CommentDetector List.removeLast on JDK 17.
# Set M3_JDK21 to a complete JDK 21 Home directory.
set -eu
: "${M3_JDK21:?Set M3_JDK21 to JDK 21 Contents/Home}"
export JAVA_OPTS="${JAVA_OPTS:-} -Dorg.gradle.java.home=$M3_JDK21"
flutter build apk --release
