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

  @override
  String toString() {
    return 'OpenResult(type: $type, message: $message)';
  }
}
