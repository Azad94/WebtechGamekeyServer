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


///Template for json file
Map _defaultData = {
  'service' : "Gamekey",
  'version': "0.0.1",
  'users': [],
  'games': [],
  'gamestates': []
};

User u = new User("ID", "user", "user", "name", "secr@et.com", _createdAt, "nterschrift");

Map _gamekeyMemory;
File _serverStorage = new File('\serverStorage.json');











main() async {
  /**
   * checks if _storageFile the _storageFile contains the _defaultdata,
   * if not write the _defaultData into it
   * or if the file even exists
   */
  if (!await _serverStorage.exists()  || (await _serverStorage.length() < _defaultData.length)) {
    _serverStorage.openWrite().write(JSON.encode(_defaultData));
  }

  //TODO Pretty Print von der _storageFile funktioniert nicht
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




    Response _serverResponse;
    /**
     * handles the [GET USERS] request
     * sends all registered Users as Response
     */
    _gamekeyServer.get('/users').listen((request) {
      _serverResponse = request.response;
      enableCors(_serverResponse);
      //TODO hier prettyPrint ?
      print(_gamekeyMemory['users'].toString());
      _serverResponse.status(HttpStatus.OK).json(_gamekeyMemory["users"]); //json method includes send() which contains IOSink close() --> so no close needed
    });















    //TODO                  wie mache ich die E-Mail Optional     CHECK
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
      String _newUserName = _clientRequest.param("name");
      String _newUserPwd = _clientRequest.param("pwd");
      var _newUserMail = _clientRequest.param("mail");
      var _userID = new Random.secure().nextInt(0xFFFFFFFF);

      /**
       * validates the given parameters
       */
      if (!_checkUserParams(_serverResponse ,_newUserName, _newUserPwd, _newUserMail))
        return null;
      print("KERNEL");

      /**
       * creates the user after the params have been validated
       */
      var user = {
        'type' : "user",
        'name' : _newUserName,
        'id' : _userID.toString(),
        'created' : (new DateTime.now().toString()),
        'mail' : (_newUserMail != null) ? _newUserMail : '',
        'signature' : ''
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
















    //TODO                        CHECKED
    /**
     * returns User with given ID and Password if existing
     */
    _gamekeyServer.get('/user/:id').listen((request) async {
      ///Enabling Cors
      Response res = request.response;
      enableCors(res);

      ///Initializing Params
      var id = request.param("id");
      var pwd = request.param("pwd");
      String byname = request.param("byname");
      print("HIER"+request.param("byname").length.toString());
      //TODO hier raus ...
      if (request.input.headers.contentLength != -1) {
        print("hier kommt er nie rein");
        var map = await request.payload();
        pwd = map["pwd"] == null ? "" : map["pwd"];
        byname = map["byname"] == null ? "" : map["byname"];
      }
      Map user;

      ///Test if byname is correct
      if (!(byname.isEmpty) && (byname != 'true') && (byname != 'false')) {
        res.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: byname parameter must be 'true' or 'false' (if set), was $byname.");
        return null;
      }
      if (byname == 'true') {
        user = get_user_by_name(id, _gamekeyMemory);
      }
      if (byname == 'false' || byname.isEmpty) {
        user = get_user_by_id(id, _gamekeyMemory);
      }
      if (user == null) {
        res.status(HttpStatus.NOT_FOUND).send(
            "User not Found.");
        return null;
      }
      if (isNotAuthentic(user, pwd)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      ///Cloning user and adding alle played games and gamestates
      user = new Map.from(user);
      user['games'] = new List();
      if (_gamekeyMemory['gamestates'] != null) {
        for (Map m in _gamekeyMemory['gamestates']) {
          if (m['userid'].toString() == user["id"].toString()) {
            user['games'].add(m['gameid']);
          }
        }
      }
      res.status(HttpStatus.OK).send(JSON.encode(user));
    });











    //TODO                      CHECKED
    ///Puts user by id
    ///
    /// returns updated user if succesfull
    /**
     *
     */
    _gamekeyServer.put('/user/:id').listen((request) async {
      ///Enabling Cors
      Response res = request.response;
      enableCors(res);

      ///Initializing params
      String id = request.param("id");
      String pwd = request.param("pwd");
      String new_name = request.param("newname");
      String new_mail = request.param("newmail");
      String new_pwd = request.param("newpwd");
      if (request.input.headers.contentLength != -1) {
        var map;// = await request.payload();
        if (pwd.isEmpty) pwd = map["pwd"] == null ? "" : map["pwd"];
        if (new_name.isEmpty) new_name = map["name"] == null ? "" : map["name"];
        if (new_mail.isEmpty) new_mail = map["mail"] == null ? "" : map["mail"];
        if (new_pwd.isEmpty)
          new_pwd = map["newpwd"] == null ? "" : map["newpwd"];
      }

      ///Testing if isMail is correct
      if (!isEmail(new_mail) && !new_mail.isEmpty) {
        res.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: $new_mail is not a valid email.");
        return null;
      }

      ///Testing if user exist
      if (user_exists(new_name, _gamekeyMemory)) {
        res.status(HttpStatus.NOT_ACCEPTABLE).send(
            "User with name $new_name exists already.");
        return null;
      }
      //Reads user which has to be edited
      var user = get_user_by_id(id, _gamekeyMemory);
      //Control if isNotAuthentic
      if (isNotAuthentic(user, pwd)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      if (!new_name.isEmpty) user['name'] = new_name;
      //Not sure how to handle, edit could mean delete mail with empty string
      if (!new_mail.isEmpty) user['mail'] = new_mail;
      if (new_pwd != null || !new_pwd.isEmpty) user['signature'] =
          BASE64.encode((sha256.convert(
              UTF8.encode(id.toString() + ',' + new_pwd.toString()))).bytes);
      user['update'] = new DateTime.now().toString();
      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      //Return edited User as Json
      res.status(HttpStatus.OK).json(user);
    });
















    //TODO                          CHECKED
    ///Delete for users by id
    ///
    /// returns Success if everything worked
    /**
     *
     */
    _gamekeyServer.delete('/user/:id').listen((request) async {
      ///Enabling Cors
      Response res = request.response;
      enableCors(res);

      ///Initializing params
      ///Erinnerung bei allen Requests params abfange bevor payload auslesen
      var id = request.param("id");
      var pwd = request.param("pwd");
      //if (request.input.headers.contentLength != -1) {
      //  var map = await request.payload();
      //  pwd = map["pwd"] == null ? "" : map["pwd"];
      //}
      //Gets user which should be deleted
      var user = get_user_by_id(id, _gamekeyMemory);
      //if user does not exist send Ok(could be more than one Request,
      //so the server knows the User which should be deleted is gone)
      if (user == null) {
        res.status(HttpStatus.OK).send(
            "User not found.");
        return null;
      }
      //Control if Id/Pwd isNotAuthentic
      if (isNotAuthentic(user, pwd)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }
      //Removes the user
      if (_gamekeyMemory['users'].remove(user) == null) {
        res.status(HttpStatus.INTERNAL_SERVER_ERROR).send('Failed\n$user');
      }
      //Removes all gamestates from specific User
      List<Map> gs = new List<Map>();
      _gamekeyMemory['gamestates']
          .where((g) => g["userid"].toString() == id.toString())
          .forEach((g) => gs.add(g));
      gs.forEach((g) => _gamekeyMemory["gamestates"].remove(g));
      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      res.status(HttpStatus.OK).send("Success");
    });













    ///Gets all games
    ///
    /// Returns a list of all saved games as Json
    /**
     *
     */
    _gamekeyServer.get('/games').listen((request) {
      Response res = request.response;
      enableCors(res);
      res.status(HttpStatus.OK).json(_gamekeyMemory['games']);
    });











    //TODO              CHECKED   URL--> is not absolute überprüfen ... und wenn das Secret schon existiert nicht wieder erlauben
    ///Post for games
    ///
    ///Creates a new game with given Parameters
    /**
     *
     */
    _gamekeyServer.post('/game').listen((request) async {
      //Enabling Cors
      Response res = request.response;
      //enableCors(res);
      //Initializing params
      String name = request.param('name');
      var secret = request.param('secret');
      String url = request.param('url');
      if (request.input.headers.contentLength != -1) {
        var map;// = await request.payload();
        if (name.isEmpty) name = map["name"] == null ? "" : map["name"];
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
        //if (url.isEmpty) url = map["url"] == null ? "" : map["url"];
      }
      var id = new Random.secure().nextInt(0xFFFFFFFF);

      //Control if game is given any name
      if (name == null || name.isEmpty) {
        res.send('Game must be given a name');
      }

      //Control if Url is valid
      Uri uri = Uri.parse(url);
      if (uri != null || !url.isEmpty) {
        if (uri.isAbsolute) {
          res.status(HttpStatus.BAD_REQUEST).send("Bad Request: '" + url +
              "' is not a valid absolute url");
          return null;
        }
      }

      //Control if Url matches RegExp
      if (!url.isEmpty && !isUrl(url)) {
        res.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: '" + url + "' is not a valid absolute url");
        return null;
      }

      //Control if game already exists
      if (!_gamekeyMemory['games'].isEmpty) {
        if (game_exists(name, _gamekeyMemory)) {
          res.status(HttpStatus.BAD_REQUEST).send(
              "Game Already exists");
          return null;
        }
      }

      //Creation of game with parameters
      Map game = {
        "type" : 'game',
        "name" : name,
        "id" : id.toString(),
        "url" : uri.toString(),
        "signature" : BASE64.encode((sha256.convert(
            UTF8.encode(id.toString() + ',' + secret.toString()))).bytes),
        "created" : new DateTime.now().toString()
      };

      _gamekeyMemory['games'].add(game);
      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      res.status(HttpStatus.OK).json(game);
    });













    //TODO                      CHECKED ---> WIE FUNKTIONIERT DIESES AUTHORIZED
    ///Gets a game by id
    ///
    ///Returns game if id and secret is correct
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
        var map;// = await request.payload();
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
      }
      //Gets game by id
      var game = get_game_by_id(id, _gamekeyMemory);

      if (game == null) {
        res.status(HttpStatus.NOT_FOUND).send("Game not found");
        return null;
      }
      //Control if Signature matches input(has to be changed to isNotAuthentic)
/**      if (BASE64.encode(
          (sha256.convert(UTF8.encode(id.toString() + ',' + secret.toString())))
              .bytes) != game['signature']) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }
**/      //Copys game and adds List of users for game
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




















    //TODO                  PAYLOAD FEHLER
    ///Edits a game
    ///
    ///returns edited game if succesfull
    /**
     *
     */
    _gamekeyServer.put('/game/:id').listen((request) async {
      Response res = request.response;
      enableCors(res);
      var id = request.param('id');
      var secret = request.param('secret');
      var new_name = request.param('name');
      var new_url = request.param('url');
      var new_secret = request.param('newsecret');
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (new_name.isEmpty) new_name = map["name"] == null ? "" : map["name"];
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
       // if (new_url.isEmpty) new_url = map["url"] == null ? "" : map["url"];
        if (new_secret.isEmpty)
          new_secret = map["newsecret"] == null ? "" : map["newsecret"];
      }

      //Gets game by id
      var game = get_game_by_id(id, _gamekeyMemory);

      //Control if url is valid
      Uri uri = Uri.parse(new_url);
      if (!new_url.isEmpty && (!isUrl(new_url))) {
        res.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: '" + new_url + "' is not a valid absolute url");
        return null;
      }
      //Control if game exists
      if (!new_name.isEmpty) {
        if (game_exists(new_name, _gamekeyMemory)) {
          res.status(HttpStatus.BAD_REQUEST).send(
              "Game Already exists");
          return null;
        }
      }
      //Control if is Authentic
 /**     if (isNotAuthentic(game,secret)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }
  **/    if (!new_name.isEmpty) game['name'] = new_name;
      //Url cant be deleted
      if (!new_url.isEmpty) game['url'] = new_url;
      //new_secret cant be empty string
      if (!new_secret.isEmpty) game['signature'] = BASE64.encode((sha256.convert(
          UTF8.encode(id.toString() + ',' + new_secret.toString()))).bytes);
      game['update'] = new DateTime.now().toString();
      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      res.status(HttpStatus.OK).json(game);
    });



















    //TODO                    CHECKED ---> AUTHORIZED FEHLT NOCH
    ///Deletes game by id
    ///
    ///returns Success if game is deleted or not existent
    /**
     *
     */
    _gamekeyServer.delete('/game/:id').listen((request) async {
      //Enabling Cors
      Response res = request.response;
      enableCors(res);
      //Initializing params
      var id = request.param('id');
      var secret = request.param('secret');
      if (request.input.headers.contentLength != -1) {
        var map;// = await request.payload();
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
      }

      //Gets game by id
      var game = get_game_by_id(id, _gamekeyMemory);
      //Control if game exists
      if (game == null) {
        res.status(HttpStatus.OK).send("Game not found");
        return null;
      }
      //Control if isAuthentic(should be changed to function)
  /**    if (BASE64.encode(
          (sha256.convert(UTF8.encode(id.toString() + ',' + secret.toString())))
              .bytes) != game['signature']) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }
  **/
      //Removes game
      if (_gamekeyMemory['games'].remove(game) == null) {
        res.status(HttpStatus.OK).send('Failed\n$game');
      }

      //Removes all gamestates of said game
      List<Map> gs = new List<Map>();
      _gamekeyMemory['gamestates']
          .where((g) => g["gameid"].toString() == id.toString())
          .forEach((g) => gs.add(g));
      gs.forEach((g) => _gamekeyMemory["gamestates"].remove(g));

      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      res.status(HttpStatus.OK).send('Success');
    });


















    //TODO                        CHECKED
    ///Gets gamestates from Specific user and game
    ///
    ///
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
   /**   if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
      }
    **/
      //Gets games and user
      var game = get_game_by_id(gameid, _gamekeyMemory);
      var user = get_user_by_id(userid, _gamekeyMemory);

      //Control if either games or user does not exist
      if (user == null || game == null) {
        res.status(HttpStatus.NOT_FOUND).send(
            "User or game NOT Found.");
        return null;
      }
/**
      //Control if is Authentic
      if (isNotAuthentic(game,secret)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }
**/
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
      res.status(HttpStatus.OK).json(states);
    });
















    //TODO                      CHECKED
    ///Gets all gamestates of game by id
    ///
    ///Returns List of all gamestates from game if successfull
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
/**      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
      }
**/
      //Gets game by id and Control if exists
      var game = get_game_by_id(gameid, _gamekeyMemory);
      if (game == null) {
        res.status(HttpStatus.NOT_FOUND).send(
            "Game NOT Found.");
        return null;
      }

/**      //Control if isAuthentic
      if (isNotAuthentic(game,secret)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }
**/
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










    //TODO                    CHECKED ---> AUTHORIZED FEHLT
    ///Post for gamestates
    ///
    ///returns Gamestate if successfull
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
      //if (request.input.headers.contentLength != -1) {
      //  var map;// = await request.payload();
        //if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
        //if (state.isEmpty) state = map["state"] == null ? "" : map["state"];
      //}

      //Gets user and game
      var game = get_game_by_id(gameid, _gamekeyMemory);
      var user = get_user_by_id(userid, _gamekeyMemory);

      //Control if either user or games has not been found
      if (user == null || game == null) {
        res.status(HttpStatus.NOT_FOUND).send(
            "User or game NOT Found.");
        return null;
      }

  /**    //Control if isAuthentic
      if (isNotAuthentic(game,secret)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }
**/
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
          "created" : (new DateTime.now().toString()),
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
print("CHECK");
/**
   * if the user name is null or empty
   * return false
   */
  if (name == null || name.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Name is required");
    return false;
  }
  print("NAME CHECKED");
  /**
   * if pwd is null or empty
   * return false
   */
  if (pwd == null || pwd.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Password is required");
    return false;
  }
print("PWD CHECKED");
  /**
   *  if the given mail hasn't the standard regulations
   *  returns false
   */
  if (mail != null) {
    if (!isEmail(mail)) {
      _serverResponse.status(HttpStatus.BAD_REQUEST).send(
          "Bad Request: $mail is not a valid email.");
      return false;
    }
  }
print("MAIL CHECKED");
  /**
   * if the user already exists
   * return false
   */
  if (user_exists(name, _gamekeyMemory)) {
    _serverResponse.status(HttpStatus.CONFLICT).send(
        "Bad Reqeust: The name $name is already taken");
    return false;
  }
print("EXISTS CHECKED");
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

///Gets game by id
///
/// returns null if game not found
/**
 *
 */
Map get_game_by_id(String id, Map memory) {
  for (Map m in memory['games']) {
    if (m['id'].toString() == id.toString()) return m;
  }
  return null;
}

///Looks for existing game by id
///
/// returns false if not found
/**
 *
 */
bool game_exists(String name, Map memory) {
  for (Map m in memory['games']) {
    if (m['name'] == name) return true;
  }
  return false;
}

///Gets user by name
///
/// returns null if user not found
/**
 *
 */
Map get_user_by_name(String name, Map memory) {
  for (Map m in memory['users']) {
    if (m['name'] == name) return m;
  }
}

///Gets user by id
///
/// returns null if user not found
/**
 *
 */
Map get_user_by_id(String id, Map memory) {
  for (Map m in memory['users']) {
    if (m['id'].toString() == id.toString()) return m;
  }
}

///Looks for existing user by id
///
/// returns false if not found
/**
 *
 */
bool user_exists(String name, Map memory) {
  for (Map m in memory['users']) {
    if (m['name'] == name) return true;
  }
  return false;
}

///Control if E-Mail is correct
///
/// returns false if E-Mail has no Match with RegExp
/**
 *
 */
bool isEmail(String em) {
  String p = r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
  RegExp regExp = new RegExp(p);
  return regExp.hasMatch(em);
}

///Control if Url is correct
///
/// returns false if Url has no Match with RegExp
/**
 *
 */
bool isUrl(String url) {
  String exp = r'(https?:\/\/)';
  RegExp regExp = new RegExp(exp);
  return regExp.hasMatch(url);
}

///Authentication
///
/// returns true if Authentication failed or false if Authentic
/**
 *
 */
bool isNotAuthentic(Map map, String pwd) {
  if (map["signature"] != BASE64.encode(
      (sha256.convert(UTF8.encode(map["id"].toString() + ',' + pwd.toString())))
          .bytes)) return true;
  return false;
}


/// Enables Cross origin by editing the response header
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
      'Origin, X-Requested-With, Content-Type, Accept, Charset'
  );
}


/**

    SECRET IST AUSGEDACHT, ICH SOLLTE NUR BEI PUT DELETE GET AUF DEN
    SECRET PRÜFEN OB ES DIESEN GIBT UND DER RICHTIG IST ...







**/