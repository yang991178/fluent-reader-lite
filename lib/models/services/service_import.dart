class ServiceImport {
  String endpoint;
  String username;
  String password;
  String apiId;
  String apiKey;

  static const typeMap = {
    "f": "/settings/service/fever",
    "g": "/settings/service/greader",
    "i": "/settings/service/inoreader",
    "fb": "/settings/service/feedbin"
  };

  ServiceImport(Map<String, String> params) {
    endpoint = params["e"];
    username = params["u"];
    password = params["p"];
    apiId = params["i"];
    apiKey = params["k"];
  }
}
