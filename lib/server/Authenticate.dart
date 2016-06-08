part of serverLibrary;

/**
 * generates the Signature with the ID
 */
String _generateSignature(String id, String password) {
  return BASE64
      .encode(sha256.convert(UTF8.encode(id + "," + password)).bytes);
}

/**
 * test
 */
bool _toAuthenticate(Map entity, String password) {
  if (entity != null && password != null)
    return entity['signature'] == _generateSignature(entity['id'], password);
  else
    return false;
}
