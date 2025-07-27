# Use official Dart image
FROM dart:stable AS build

# Set working directory
WORKDIR /app

# Copy project files
COPY pubspec.yaml .
COPY lib/ lib/

# Install dependencies
RUN dart pub get

# Copy main.dart
COPY lib/main.dart .

# Compile to executable
RUN dart compile exe main.dart -o server

# Use a smaller runtime image
FROM dart:stable

WORKDIR /app
COPY --from=build /app/server .

# Command to run the app
CMD ["./server"]