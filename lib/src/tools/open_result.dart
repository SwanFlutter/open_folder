/// Result type enum for folder opening operations
enum ResultType {
  /// Operation completed successfully
  done,

  /// Operation failed with error
  error,

  /// File or folder not found
  fileNotFound,

  /// No application available to handle the operation
  noAppToOpen,

  /// Permission denied
  permissionDenied,
}

/// Result class for folder opening operations
class OpenResult {
  /// The type of result
  final ResultType type;

  /// Message describing the result
  final String message;

  const OpenResult({required this.type, required this.message});

  /// Create OpenResult from JSON map
  factory OpenResult.fromJson(Map<String, dynamic> json) {
    return OpenResult(
      type: _parseResultType(json['type'] as String),
      message: json['message'] as String,
    );
  }

  /// Convert OpenResult to JSON map
  Map<String, dynamic> toJson() {
    return {'type': type.name, 'message': message};
  }

  static ResultType _parseResultType(String typeString) {
    switch (typeString) {
      case 'done':
        return ResultType.done;
      case 'error':
        return ResultType.error;
      case 'fileNotFound':
        return ResultType.fileNotFound;
      case 'noAppToOpen':
        return ResultType.noAppToOpen;
      case 'permissionDenied':
        return ResultType.permissionDenied;
      default:
        return ResultType.error;
    }
  }

  /// Returns true if the operation was successful
  bool get isSuccess => type == ResultType.done;

  /// Returns true if the operation failed with an error
  bool get isError =>
      type == ResultType.error ||
      type == ResultType.fileNotFound ||
      type == ResultType.noAppToOpen ||
      type == ResultType.permissionDenied;

  /// Returns true if the operation was cancelled
  bool get isCancelled =>
      false; // Currently not used, but kept for API compatibility

  /// Returns true if file or folder was not found
  bool get isFileNotFound => type == ResultType.fileNotFound;

  /// Returns true if no application is available to handle the operation
  bool get isNoAppToOpen => type == ResultType.noAppToOpen;

  /// Returns true if permission was denied
  bool get isPermissionDenied => type == ResultType.permissionDenied;

  @override
  String toString() {
    return 'OpenResult(type: $type, message: $message)';
  }
}
