import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:start/start.dart';
import 'package:crypto/crypto.dart';
import 'package:Webtech_GamekeyServer/serverLibrary.dart';
/**
 * START --> Sinatra inspired Web-Framework
 * https://www.dartdocs.org/documentation/start/0.2.7/
 */


Map _usermap = new Map<String, User>();
Map _gameMap = new Map<String, Game>();
Defaults _defaultSettings = new Defaults();
DateTime _createdAt = new DateTime.now();
User _user;
num auth = 0;
///Template for json file
Map _defaultData = {
  'service' : "Gamekey",
  'version': "0.0.1",
  'users': [],
  'games': [],
  'gamestates': []
};


Map _gamekeyMemory;
File _serverStorage = new File('\serverStorage.json');








//TODO Pretty Print für die _storageFile funktioniert nicht



main() async {

  /**
   * checks if _storageFile the _storageFile contains the _defaultdata,
   * if not write the _defaultData into it
   * or if the file even exists
   */
  if (!await _serverStorage.exists()  || (await _serverStorage.length() < _defaultData.length)) {
    _serverStorage.openWrite().write(JSON.encode(_defaultData));
  }

  /**
      JsonEncoder encoder = new JsonEncoder.withIndent('  ');
      _userMap.forEach((k,v) {
      prettyprint = prettyprint + encoder.convert(_userMap[k]._mapOneUserToEncode());
      });
   */

  /**
   * write the existing information (Map) into the the
   * current _gamekeyMemory
   */
  _gamekeyMemory = JSON.decode(await _serverStorage.readAsString());

  /**
   * Initializes the server on Localhost and on the given Port
   */
  start(host: '0.0.0.0', port: 6060).then((Server _gamekeyServer) {
    _gamekeyServer.static('web');

    /**
     * response which is going to be
     * send to the client according
     * to the request he send
     */
    Response _serverResponse;

    /**
     * handles the get Users request
     * sends all registered Users as Response
     */
    _gamekeyServer.get('/users').listen((request) {
      _serverResponse = request.response;
      enableCors(_serverResponse);
      //json method includes send() which contains IOSink close() --> so no close needed
      _serverResponse.status(HttpStatus.OK).json(_gamekeyMemory["users"]);
    });

    /**
     * Posts as User on the GameKeyServer with
     * Name, Passoword and E-Mail (optional) as parameter
     * returns the User if created
     */
    _gamekeyServer.post('/user').listen((_clientRequest) async {

      _serverResponse = _clientRequest.response;
      enableCors(_serverResponse);

      /**
       * retrieves the parameteres from the
       * Client request
       */
      try{
      String _userName = _clientRequest.param("name");
      String _userPwd = _clientRequest.param("pwd");
      var _userMail = _clientRequest.param("mail");
      var _userID = new Random.secure().nextInt(0xFFFFFFFF);

      if (_clientRequest.input.headers.contentLength != -1) {
        var map = await _clientRequest.payload();
        if (_userName.isEmpty) _userName = map["name"];
        if (_userPwd.isEmpty) _userPwd = map["pwd"];
        if (_userMail.isEmpty) _userMail = map["mail"];
      }

      /**
       * validates the given parameters
       */
      if (!_checkUserParams(_serverResponse ,_userName, _userPwd, _userMail))
        return null;

      /**
       * creates the user after the params have been validated
       */

      var user = {
        'type' : "user",
        'name' : _userName,
        'id' : _userID.toString(),
        'created' : (new DateTime.now().toIso8601String()),
        'mail' : _userMail,
        'signature' : _generateSignature(_userID.toString(), _userPwd)
      };

      /**
       * adds the user and
       */
      _gamekeyMemory["users"].add(user);
      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      _serverResponse.status(HttpStatus.OK).json(user);
      }catch(error, stacktrace){
        print(error);
        print(stacktrace);
      }
    });

    /**
     * returns User with given ID and Password if existing
     */
    _gamekeyServer.get('/user/:id').listen((request) async {
      Map _searchedUser;
      _serverResponse = request.response;
      enableCors(_serverResponse);

      var id = request.param("id");
      var pwd = request.param("pwd");
      String _userByname = request.param("byname");

      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        pwd = map["pwd"] == null ? "" : map["pwd"];
        _userByname = map["byname"] == null ? "" : map["byname"];
      }


      if (!(_userByname.isEmpty) && (_userByname != 'true') && (_userByname != 'false')) {
        _serverResponse.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: byname parameter must be 'true' or 'false' (if set), was $_userByname.");
        return null;
      }
      if (_userByname == 'true') {
        _searchedUser = get_user_by_name(_userByname, _gamekeyMemory);
      }
      if (_userByname == 'false' || _userByname.isEmpty) {
        _searchedUser = get_user_by_id(id, _gamekeyMemory);
      }
      if (_searchedUser == null) {
        _serverResponse.status(HttpStatus.NOT_FOUND).send(
            "User not Found.");
        return null;
      }

      if (!_toAuthenticate(_searchedUser, pwd)) {
        //print("unauthorized");
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      ///Cloning user and adding alle played games and gamestates
      _searchedUser = new Map.from(_searchedUser);
      _searchedUser['games'] = new List();
      if (_gamekeyMemory['gamestates'] != null) {
        for (Map m in _gamekeyMemory['gamestates']) {
          if (m['userid'].toString() == _searchedUser["id"].toString()) {
            _searchedUser['games'].add(m['gameid']);
          }
        }
      }
      _serverResponse.status(HttpStatus.OK).send(JSON.encode(_searchedUser));
    });

    /**
     *
     */
    _gamekeyServer.put('/user/:id').listen((request) async {
    _serverResponse = request.response;
      enableCors(_serverResponse);

      String id = request.param("id");
      String pwd = request.param("pwd");
      String new_name = request.param("name");
      String new_mail = request.param("mail");
      String new_pwd = request.param("newpwd");
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (pwd.isEmpty) pwd = map["pwd"] == null ? "" : map["pwd"];
        if (new_name.isEmpty) new_name = map["name"] == null ? "" : map["name"];
        if (new_mail.isEmpty) new_mail = map["mail"] == null ? "" : map["mail"];
        if (new_pwd.isEmpty)
          new_pwd = map["newpwd"] == null ? "" : map["newpwd"];
      }

      if (!isEmail(new_mail) && !new_mail.isEmpty) {
        _serverResponse.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: $new_mail is not a valid email.");
        return null;
      }

      if (user_exists(new_name, _gamekeyMemory)) {
        _serverResponse.status(HttpStatus.NOT_ACCEPTABLE).send(
            "User with name $new_name exists already.");
        return null;
      }
      //Reads user which has to be edited
      var user = get_user_by_id(id, _gamekeyMemory);

      if (!_toAuthenticate(user, pwd)) {
        auth++;
        //print("unauthorized");
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      if (!new_name.isEmpty) user['name'] = new_name;
      //Not sure how to handle, edit could mean delete mail with empty string
      if (!new_mail.isEmpty) user['mail'] = new_mail;
      if (new_pwd != null || !new_pwd.isEmpty) user['signature'] = BASE64.encode((sha256.convert(
          UTF8.encode(id.toString() + ',' + new_pwd.toString()))).bytes);
      user['update'] = new DateTime.now().toString();

      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      //Return edited User as Json
      _serverResponse.status(HttpStatus.OK).json(user);
    });

    /**
     *
     */
    _gamekeyServer.delete('/user/:id').listen((request) async {
      _serverResponse = request.response;
      enableCors(_serverResponse);

      ///Erinnerung bei allen Requests params abfange bevor payload auslesen
      var id = request.param("id");
      var pwd = request.param("pwd");
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        pwd = map["pwd"] == null ? "" : map["pwd"];
      }
      //Gets user which should be deleted
      var user = get_user_by_id(id, _gamekeyMemory);
      //if user does not exist send Ok(could be more than one Request,
      //so the server knows the User which should be deleted is gone)
      if (user == null) {
        _serverResponse.status(HttpStatus.OK).send(
            "User not found.");
        return null;
      }

     // print(!_toAuthenticate(user,pwd));
      if (!_toAuthenticate(user, pwd)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      //Removes the user
      if (_gamekeyMemory['users'].remove(user) == null) {
        _serverResponse.status(HttpStatus.INTERNAL_SERVER_ERROR).send('Failed\n$user');
      }
      //Removes all gamestates from specific User
      List<Map> gs = new List<Map>();
      _gamekeyMemory['gamestates']
          .where((g) => g["userid"].toString() == id.toString())
          .forEach((g) => gs.add(g));
      gs.forEach((g) => _gamekeyMemory["gamestates"].remove(g));
      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      _serverResponse.status(HttpStatus.OK).send("Success");
    });













    ///Gets all games
    ///
    /// Returns a list of all saved games as Json
    /**
     *
     */
    _gamekeyServer.get('/games').listen((request) {
      _serverResponse = request.response;
      enableCors(_serverResponse);
      _serverResponse.status(HttpStatus.OK).json(_gamekeyMemory['games']);
    });











    _gamekeyServer.post('/game').listen((request) async {

      //Enabling Cors
      _serverResponse = request.response;
      enableCors(_serverResponse);
      //Initializing params
      String name = request.param('name');
      var secret = request.param('secret');
      String url = request.param('url');
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (name.isEmpty) name = map["name"] == null ? "" : map["name"];
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
        if (url.isEmpty) url = map["url"] == null ? "" : map["url"];
      }
      var id = new Random.secure().nextInt(0xFFFFFFFF);

      //Control if Url is valid
      Uri uri = Uri.parse(url);
      if (uri != null || !url.isEmpty) {
        if (uri.isAbsolute) {
          _serverResponse.status(HttpStatus.BAD_REQUEST).send("Bad Request: '" + url +
              "' is not a valid absolute url");
          return null;
        }
      }

      if(!_checkGameParams(_serverResponse, name, secret, url)){
        return null;
      }

      //Creation of game with parameters
      Map game = {
        "type" : 'game',
        "name" : name,
        "id" : id.toString(),
        "url" : uri.toString(),
        "signature" : BASE64.encode((sha256.convert(
            UTF8.encode(id.toString() + ',' + secret.toString()))).bytes),
        "created" : new DateTime.now().toUtc().toIso8601String()
      };

      _gamekeyMemory['games'].add(game);
      _serverResponse.status(HttpStatus.OK).json(game);
      _serverResponse.close();
      await _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
    });

    /**
     *
     */
    _gamekeyServer.get('/game/:id').listen((request) async {
      //Enabling Cors
      Response res = request.response;
      enableCors(res);
      //Initializing params
      var secret = request.param('secret');
      var id = request.param('id');
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
      }
      //Gets game by id
      var game = get_game_by_id(id, _gamekeyMemory);

      if (game == null) {
        res.status(HttpStatus.NOT_FOUND).send("Game not found");
        return null;
      }

      // print(!_toAuthenticate(user,pwd));
      if (!_toAuthenticate(game, secret)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

     //Copys game and adds List of users for game
      game = new Map.from(game);
      game['users'] = new List();
      if (_gamekeyMemory['gamestates'] != null) {
        for (Map m in _gamekeyMemory['gamestates']) {
          if (m['gameid'].toString() == id.toString()) {
            game['users'].add(m['userid']);
          }
        }
      }
      res.status(HttpStatus.OK).json(game);
    });

    /**
     *
     */
    _gamekeyServer.put('/game/:id').listen((request) async {
      _serverResponse = request.response;
      enableCors(_serverResponse);
      var id = request.param('id');
      var secret = request.param('secret');
      var new_name = request.param('name');
      var new_url = request.param('url');
      var new_secret = request.param('secret');

      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (new_name.isEmpty) new_name = map["name"] == null ? "" : map["name"];
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
        if (new_url.isEmpty) new_url = map["url"] == null ? "" : map["url"];
        if (new_secret.isEmpty)
          new_secret = map["newsecret"] == null ? "" : map["newsecret"];
      }

      //Gets game by id
      var game = get_game_by_id(id, _gamekeyMemory);

      //Control if url is valid
      Uri uri = Uri.parse(new_url);
      if (!new_url.isEmpty && (!isUrl(new_url))) {
        _serverResponse.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: '" + new_url + "' is not a valid absolute url");
        return null;
      }
      //Control if game exists
      if (!new_name.isEmpty) {
        if (game_exists(new_name, _gamekeyMemory)) {
          _serverResponse.status(HttpStatus.BAD_REQUEST).send(
              "Game Already exists");
          return null;
        }
      }

      // print(!_toAuthenticate(user,pwd));
      if (!_toAuthenticate(game, secret)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      if (!new_name.isEmpty) game['name'] = new_name;
      //Url cant be deleted
      if (!new_url.isEmpty) game['url'] = new_url;
      //new_secret cant be empty string

      if (!new_secret.isEmpty) game['signature'] = _generateSignature(id.toString(), new_secret);
      game['update'] = new DateTime.now().toString();

      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      _serverResponse.status(HttpStatus.OK).json(game);
    });

    /**
     *
     */
    _gamekeyServer.delete('/game/:id').listen((request) async {
      //Enabling Cors
      _serverResponse = request.response;
      enableCors(_serverResponse);
      //Initializing params
      var id = request.param('id');
      var secret = request.param('secret');
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
      }

      //Gets game by id
      var game = get_game_by_id(id, _gamekeyMemory);
      //Control if game exists
      if (game == null) {
        _serverResponse.status(HttpStatus.OK).send("Game not found");
        return null;
      }

      // print(!_toAuthenticate(user,pwd));
      if (!_toAuthenticate(game, secret)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      //Removes game
      if (_gamekeyMemory['games'].remove(game) == null) {
        _serverResponse.status(HttpStatus.OK).send('Failed\n$game');
      }

      //Removes all gamestates of said game
      List<Map> gs = new List<Map>();
      _gamekeyMemory['gamestates']
          .where((g) => g["gameid"].toString() == id.toString())
          .forEach((g) => gs.add(g));
      gs.forEach((g) => _gamekeyMemory["gamestates"].remove(g));

      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      _serverResponse.status(HttpStatus.OK).send('Success');
    });


















    /**
     *
     */
    _gamekeyServer.get('/gamestate/:gameid/:userid').listen((request) async {
      //Enabling Cors
      Response res = request.response;
      enableCors(res);

      var gameid = request.param("gameid");
      var userid = request.param("userid");
      var secret = request.param("secret");
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
      }

      //Gets games and user
      var game = get_game_by_id(gameid, _gamekeyMemory);
      var user = get_user_by_id(userid, _gamekeyMemory);


      //Control if either games or user does not exist
      if (user == null || game == null) {
        res.status(HttpStatus.NOT_FOUND).send(
            "User or game NOT Found.");
        return null;
      }

      // print(!_toAuthenticate(user,pwd));
      if (!_toAuthenticate(game, secret)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      //Lists all states from game and User
      var states = new List<Map>();
      for (Map m in _gamekeyMemory['gamestates']) {
        if (m['gameid'].toString() == gameid.toString() &&
            m['userid'].toString() == userid.toString()) {
          var state = new Map.from(m);
          state["gamename"] = game["name"];
          state["username"] = user["name"];
          states.add(state);
        }
      }
      //Sort states
      states.sort((m, n) =>
          DateTime.parse(n["created"]).compareTo(DateTime.parse(m["created"])));
      JsonEncoder encode;
      /**
       * JsonEncoder encoder = new JsonEncoder.withIndent('  ');
          _userMap.forEach((k,v) {
          prettyprint = prettyprint + encoder.convert(_userMap[k]._mapOneUserToEncode());
          });
       */
      res.status(HttpStatus.OK).json(states);
    });
















    /**
     *
     */
    _gamekeyServer.get('/gamestate/:gameid').listen((request) async {
      //Enabling Cors
      Response res = request.response;
      enableCors(res);
      //Initializing params
      var gameid = request.param('gameid');
      var secret = request.param('secret');
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
      }

      //Gets game by id and Control if exists
      var game = get_game_by_id(gameid, _gamekeyMemory);
      if (game == null) {
        res.status(HttpStatus.NOT_FOUND).send(
            "Game NOT Found.");
        return null;
      }

      // print(!_toAuthenticate(user,pwd));
      if (!_toAuthenticate(game, secret)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      //List all states of game
      var states = new List();
      for (Map m in _gamekeyMemory['gamestates']) {
        if (m['gameid'].toString() == gameid.toString()) {
          var state = new Map.from(m);
          state["gamename"] = game["name"];
          state["username"] = get_user_by_id(m["userid"],_gamekeyMemory)["name"];
          states.add(state);
        }
      }
      res.status(HttpStatus.OK).json(states);
    });










    /**
     *
     */
    _gamekeyServer.post('/gamestate/:gameid/:userid').listen((request) async {
      //Eabling Cors
      Response res = request.response;
      enableCors(res);
      //Initializing params
      var gameid = request.param('gameid');
      var userid = request.param('userid');
      var secret = request.param('secret');
      var state = request.param('state');
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
        if (state.isEmpty) state = map["state"] == null ? "" : map["state"];
      }

      //Gets user and game
      var game = get_game_by_id(gameid, _gamekeyMemory);
      var user = get_user_by_id(userid, _gamekeyMemory);

      //Control if either user or games has not been found
      if (user == null || game == null) {
        res.status(HttpStatus.NOT_FOUND).send(
            "User or game NOT Found.");
        return null;
      }

      // print(!_toAuthenticate(user,pwd));
      if (!_toAuthenticate(game, secret)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      //Try/Catch to test if state is crrect Json
      try {
        state = JSON.decode(state);

        if (state == null || state
            .toString()
            .isEmpty) {
          request.response.status(HttpStatus.BAD_REQUEST).send(
              "Bad request: state must not be empty, was $state");
          return null;
        }

        //Creates new Gamestate
        var gamestate = {
          "type" : 'gamestate',
          "gameid" : gameid,
          "userid" : userid,
          "created" : (new DateTime.now().toUtc().toIso8601String()),
          "state" : state
        };

        _gamekeyMemory["gamestates"].add(gamestate);
        _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
        res.status(HttpStatus.OK).json(gamestate);

      } on NoSuchMethodError catch (e) {
        print(e);
        res.status(HttpStatus.BAD_REQUEST).send(
            'Bad request: state must be provided as valid JSON, was $state');
      }
    });
  });


}











bool _checkUserParams(Response _serverResponse, String name, String pwd, String mail){
/**
   * if the user name is null or empty
   * return false
   */
  if (name == null || name.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Name is required");
    return false;
  }
  /**
   * if pwd is null or empty
   * return false
   */
  if (pwd == null || pwd.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Password is required");
    return false;
  }

  /**
   *  if the given mail hasn't the standard regulations
   *  returns false
   */
  if(mail != null){
    if (!isEmail(mail)) {
      _serverResponse.status(HttpStatus.BAD_REQUEST).send(
         "Bad Request: $mail is not a valid email.");
     return false;
    }
  }
  /**
   * if the user already exists
   * return false
   */
  if (user_exists(name, _gamekeyMemory)) {
    _serverResponse.status(HttpStatus.CONFLICT).send(
        "Bad Reqeust: The name $name is already taken");
    return false;
  }
  return true;
}

bool _checkGameParams(Response _serverResponse, String name, String pwd, String url){

  /**
   * if the user name is null or empty
   * return false
   */
  if (name == null || name.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Name is required");
    return false;
  }

  /**
   * if pwd is null or empty
   * return false
   */
  if (pwd == null || pwd.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Password is required");
    return false;
  }

  /**
   *  if the given mail hasn't the standard regulations
   *  returns false
   */
  //Control if Url matches RegExp
  if (!url.isEmpty && !isUrl(url)) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: '" + url + "' is not a valid absolute url");
    return null;
  }

  /**
   * if the user already exists
   * return false
   */
  if (game_exists(name, _gamekeyMemory)) {
    _serverResponse.status(HttpStatus.CONFLICT).send(
        "Bad Reqeust: The name $name is already taken");
    return false;
  }

  return true;
}












/**
 *
 */
void t(){
  var user = {
    'type' : "user",
    'name' : "Name",
    'id' : "ID",
    'created' : (new DateTime.now().toString()),
    'mail' : "mail",
    'signature' : "signature"
  };
  _gamekeyMemory["users"].add(user);

  var users = {
    'type' : "user",
    'name' : "Malte",
    'id' : "Game",
    'created' : (new DateTime.now().toString()),
    'mail' : "Grebe@m.com",
    'signature' : "GREBEN"
  };
  _gamekeyMemory["users"].add(users);
  _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
}

/**
 *
 */
Map get_game_by_id(String id, Map memory) {
  for (Map m in memory['games']) {
    if (m['id'].toString() == id.toString()) return m;
  }
  return null;
}

/**
 *
 */
bool game_exists(String name, Map memory) {
  for (Map m in memory['games']) {
    if (m['name'] == name) return true;
  }
  return false;
}

/**
 *
 */
Map get_user_by_name(String name, Map memory) {
  for (Map m in memory['users']) {
    if (m['name'] == name) return m;
  }
}

/**
 *
 */
Map get_user_by_id(String id, Map memory) {
  for (Map m in memory['users']) {
    if (m['id'].toString() == id.toString()) return m;
  }
}

/**
 *
 */
bool user_exists(String name, Map memory) {
  for (Map m in memory['users']) {
    if (m['name'] == name) return true;
  }
  return false;
}

/**
 *
 */
bool isEmail(String em) {
  String p = r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
  RegExp regExp = new RegExp(p);
  if (em == null || em.length == 0) return true;
  return regExp.hasMatch(em);
}

/**
 *
 */
bool isUrl(String url) {
  String exp = r'(https?:\/\/)';
  RegExp regExp = new RegExp(exp);
  return regExp.hasMatch(url);
}

/**
 *
 */
bool _authenticUser(Map map, String pwd) {
  if (map["signature"] != BASE64.encode(
      (sha256.convert(UTF8.encode(map["id"].toString() + ',' + pwd.toString())))
          .bytes)) return true;
  return false;
}

bool _auth(Map map, var id, String signature){
  if(map["signature"] != BASE64.encode(
      (sha256.convert(UTF8.encode(id.toString() + ',' + signature.toString())))
        .bytes)) return true;
  return false;
}


/**
 *
 */
void enableCors(Response response) {
  response.header('Access-Control-Allow-Origin',
      '*'
  );
  response.header('Access-Control-Allow-Methods',
      'POST, GET, DELETE, PUT, OPTIONS'
  );
  response.header('Access-Control-Allow-Headers',
      'Origin, X-Requested-With, Content-Type, Accept, Charset,'
          'charset, pwd, secret, name, mail, newpwd'
  );
}

String _generateSignature(String id, String password) {
  return BASE64
      .encode(sha256.convert(UTF8.encode(id + "," + password)).bytes);
}

/**
 * test
 */
bool _toAuthenticate(Map entity, String password) {
    if(entity['signature'] == _generateSignature(entity['id'].toString(), password))
    return true;
    return false;
}
