part of serverLibrary;

String createSignature(String id, String pwdOrSecret)
{
  return BASE64.encode(sha256.convert(UTF8.encode(id+","+pwdOrSecret)).bytes);
}

bool athenticate(Map entity, String pwdOrSecret)
{
  return entity['signature'] == createSignature(entity['id'],pwdOrSecret);
}