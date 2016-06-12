import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:start/start.dart';
import 'package:crypto/crypto.dart';
import 'package:Webtech_GamekeyServer/serverLibrary.dart';

/**
 * Default Data that is written into
 * the empty file
 */
Map _defaultData = {
  'service' : "Gamekey",
  'version': "0.0.1",
  'users': [],
  'games': [],
  'gamestates': []
};

/**
 * used for savin the data
 * during the runtime
 */
Map _runtimeServerMemory;

/**
 * saves the information of the server
 * till the next session of usage
 */
File _serverStorage = new File('\serverStorage.json');

/**
 * response which is going to be
 * send to the client according
 * to the request received
 */
Response _serverResponse;


/**
 * Contains the Restful Api of the Gamekey Server for
 * the Webtechnology Project Pac-Man
 */
main() async {

  /**
   * write the _defaultData into the _serverStorage
   * if the _storageFile doesn't exist and the _defaultData
   * isn't written into it
   */
  if (!await _serverStorage.exists()  || (await _serverStorage.length() < _defaultData.length)) {
    _serverStorage.openWrite().write(JSON.encode(_defaultData));
  }
  /**
   * write the existing data into the _serverMemory
   */
  else
  _runtimeServerMemory = JSON.decode(await _serverStorage.readAsString());

  /**
   * Initializes the server on Localhost and on the given Port
   */
  start(host: '0.0.0.0', port: 6060).then((Server _gamekeyServer) {
    _gamekeyServer.static('web');

    /**
     * handles the GET USERS request
     *
     * @return 200 OK, response includes all the registered Users
     */
    _gamekeyServer.get('/users').listen((_clientRequest) {
      _serverResponse = _clientRequest.response;
      enableCors(_serverResponse);
      _serverResponse.status(HttpStatus.OK).json(_runtimeServerMemory["users"]);
    });


    /**
     * handles the POST USER Request
     *
     * Posts as User on the GameKeyServer with the required
     * parameters
     *
     * @param name Name of the User.
     * @param pwd Password of the User, which is used for the authentication.
     * @mail -- Mail of the User (is optional).
     *
     * @return 200 OK, if user the was created successfully
     * @return 400 BAD_REQUEST, if any of the param is null, empty
     *                          or not acceptable
     * @return 409 CONFLICT, if the user already exists
     */
    _gamekeyServer.post('/user').listen((_clientRequest) async {

      _serverResponse = _clientRequest.response;
      enableCors(_serverResponse);

      try{

        /**
         * retrieves the parameters from the
         * Client request
         */
        String _userName = _clientRequest.param("name");
        String _userPwd = _clientRequest.param("pwd");
        var _userMail = _clientRequest.param("mail");
        var _userID = new Random.secure().nextInt(0xFFFFFFFF);

        /**
         * retrieves the parameters from the
         * payload of the Client request
         */
        if (_clientRequest.input.headers.contentLength != -1) {
          var map = _clientRequest.payload();
          if (_userName.isEmpty) _userName = map["name"];
          if (_userPwd.isEmpty) _userPwd = map["pwd"];
          if (_userMail.isEmpty) _userMail = map["mail"];
        }

        if (!_validateUserParams(_serverResponse ,_userName, _userPwd, _userMail))
          return null;

        /**
         * creates the user after validation which is
         * supposed to be added
         */
        var user = {
          'type' : "user",
          'name' : _userName,
          'id' : _userID.toString(),
          'created' : (new DateTime.now()..toUtc().toIso8601String()),
          'mail' : _userMail,
          'signature' : _generateSignature(_userID.toString(), _userPwd)
        };

        /**
         * adds the user to the runtime Memory
         */
        _runtimeServerMemory["users"].add(user);

        /**
         * writes the new data into the file
         */
        _serverStorage.openWrite().write(JSON.encode(_runtimeServerMemory));

        /**
         * respond for the Client contains the new User
         */
        _serverResponse.status(HttpStatus.OK).json(user);
      }catch(error, stacktrace){
        print(error);
        print(stacktrace);
      }
    });


    /**
     * handles the GET USER ID Request
     *
     * Retireves the User which is searched for.
     *
     * @param id Id of the User.
     * @param pwd Password of the User, which is used for the authentication.
     *
     * @return 200 OK, if the User was found
     * @return 400 BAD_REQUEST, if any of the param is null, empty
     *                          or not acceptable
     * @return 401 UNAUTHORIZED, if the credentials are wrong
     * @return 404 NOT_FOUND, if the User doesn't exist
     */
    _gamekeyServer.get('/user/:id').listen((request) async {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * the user that is beeing searched
       */
      Map _searchedUser;

      /**
       * retrieves the parameters from the
       * Client request
       */
      var id = request.param("id");
      var pwd = request.param("pwd");
      String _userByname = request.param("byname");

      /**
       * retrieves the parameters from the
       * payload of the Client request
       */
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        pwd = map["pwd"] == null ? "" : map["pwd"];
        _userByname = map["byname"] == null ? "" : map["byname"];
      }

      /**
       * validates if the parameter byname isn't empty and if it has
       * an acceptable argument
       *
       * @return null Status 400 BAD_REQUEST, if byname is not acceptable
       */
      if (!(_userByname.isEmpty) && (_userByname != 'true') && (_userByname != 'false')) {
        _serverResponse.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: byname parameter must be 'true' or 'false' (if set), was $_userByname.");
        return null;
      }

      if (_userByname == 'true') {
        _searchedUser = get_user_by_name(id, _runtimeServerMemory);
      }

      if (_userByname == 'false' || _userByname.isEmpty) {
        _searchedUser = get_user_by_id(id, _runtimeServerMemory);
      }

      if (!_toAuthenticate(_searchedUser, pwd)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      /**
       * Duplicates the user and adds all its games and gamestates
       */
      _searchedUser = new Map.from(_searchedUser);
      _searchedUser['games'] = new List();
      if (_runtimeServerMemory['gamestates'] != null) {
        for (Map m in _runtimeServerMemory['gamestates']) {
          if (m['userid'].toString() == _searchedUser["id"].toString()) {
            _searchedUser['games'].add(m['gameid']);
          }
        }
      }

      /**
       * respond for the Client contains the searched User
       */
      _serverResponse.status(HttpStatus.OK).send(JSON.encode(_searchedUser));
    });

    /**
     *
        #
        # Updates a user.
        #
        # @param :id Unique identifier of the user (the id is never changed!). Required. Parameter is part of the REST-URI!
        # @param pwd Existing password of the user (used for authentication). Required. Parameter is part of request body.
        # @param new_name Changes name of the user to provided new name. Optional. Parameter is part of request body.
        # @param new_mail Changes mail of the user to provided new mail. Optional. Parameter is part of request body.
        # @param new_pwd Changes password of the user to a new password. Optional. Parameter is part of request body.
        #
        # @return 200 OK, on successfull update (response body includes JSON representation of updated user)
        # @return 400, on invalid mail (response body includes error message)
        # @return 401, on non matching access credentials (response body includes error message)
        # @return 409, on already existing new name (response body includes error message)

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

      if (user_exists(new_name, _runtimeServerMemory)) {
        _serverResponse.status(HttpStatus.NOT_ACCEPTABLE).send(
            "User with name $new_name exists already.");
        return null;
      }
      //Reads user which has to be edited
      var user = get_user_by_id(id, _runtimeServerMemory);

      if (!_toAuthenticate(user, pwd)) {
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

      _serverStorage.openWrite().write(JSON.encode(_runtimeServerMemory));
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
      var user = get_user_by_id(id, _runtimeServerMemory);
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
      if (_runtimeServerMemory['users'].remove(user) == null) {
        _serverResponse.status(HttpStatus.INTERNAL_SERVER_ERROR).send('Failed\n$user');
      }
      //Removes all gamestates from specific User
      List<Map> gs = new List<Map>();
      _runtimeServerMemory['gamestates']
          .where((g) => g["userid"].toString() == id.toString())
          .forEach((g) => gs.add(g));
      gs.forEach((g) => _runtimeServerMemory["gamestates"].remove(g));
      _serverStorage.openWrite().write(JSON.encode(_runtimeServerMemory));
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
      _serverResponse.status(HttpStatus.OK).json(_runtimeServerMemory['games']);
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

      _runtimeServerMemory['games'].add(game);
      _serverResponse.status(HttpStatus.OK).json(game);
      _serverResponse.close();
      await _serverStorage.openWrite().write(JSON.encode(_runtimeServerMemory));
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
      var game = get_game_by_id(id, _runtimeServerMemory);

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
      if (_runtimeServerMemory['gamestates'] != null) {
        for (Map m in _runtimeServerMemory['gamestates']) {
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
      var game = get_game_by_id(id, _runtimeServerMemory);

      //Control if url is valid
      Uri uri = Uri.parse(new_url);
      if (!new_url.isEmpty && (!isUrl(new_url))) {
        _serverResponse.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: '" + new_url + "' is not a valid absolute url");
        return null;
      }
      //Control if game exists
      if (!new_name.isEmpty) {
        if (game_exists(new_name, _runtimeServerMemory)) {
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

      _serverStorage.openWrite().write(JSON.encode(_runtimeServerMemory));
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
      var game = get_game_by_id(id, _runtimeServerMemory);
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
      if (_runtimeServerMemory['games'].remove(game) == null) {
        _serverResponse.status(HttpStatus.OK).send('Failed\n$game');
      }

      //Removes all gamestates of said game
      List<Map> gs = new List<Map>();
      _runtimeServerMemory['gamestates']
          .where((g) => g["gameid"].toString() == id.toString())
          .forEach((g) => gs.add(g));
      gs.forEach((g) => _runtimeServerMemory["gamestates"].remove(g));

      _serverStorage.openWrite().write(JSON.encode(_runtimeServerMemory));
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
      var game = get_game_by_id(gameid, _runtimeServerMemory);
      var user = get_user_by_id(userid, _runtimeServerMemory);


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
      for (Map m in _runtimeServerMemory['gamestates']) {
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
      var game = get_game_by_id(gameid, _runtimeServerMemory);
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
      for (Map m in _runtimeServerMemory['gamestates']) {
        if (m['gameid'].toString() == gameid.toString()) {
          var state = new Map.from(m);
          state["gamename"] = game["name"];
          state["username"] = get_user_by_id(m["userid"],_runtimeServerMemory)["name"];
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
      var game = get_game_by_id(gameid, _runtimeServerMemory);
      var user = get_user_by_id(userid, _runtimeServerMemory);

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

        _runtimeServerMemory["gamestates"].add(gamestate);
        _serverStorage.openWrite().write(JSON.encode(_runtimeServerMemory));
        res.status(HttpStatus.OK).json(gamestate);

      } on NoSuchMethodError catch (e) {
        print(e);
        res.status(HttpStatus.BAD_REQUEST).send(
            'Bad request: state must be provided as valid JSON, was $state');
      }
    });
  });
}



/**
 * checks if the parameters given are valid
 *
 * @return false and send 400 BAR_REQUEST if any of the params
 *         is null or empty
 * @return false and send 409 CONFLICT, if the user already exists
 * @return true if all the params are valid
 */
bool _validateUserParams(Response _serverResponse, String name, String pwd, String mail){

  /**
   * if the user name is null or empty
   * @return false and Status 400 Bad Request
   */
  if (name == null || name.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Name is required");
    return false;
  }
  /**
   * if pwd is null or empty
   * @return false and Status 400 BAD_REQUEST
   */
  if (pwd == null || pwd.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Password is required");
    return false;
  }

  /**
   *  if the given mail hasn't the standard regulations
   *  @returns false and Status 400 BAD_REQUEST
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
   * @return false and Status 409 CONFLICT
   */
  if (user_exists(name, _runtimeServerMemory)) {
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
  if (game_exists(name, _runtimeServerMemory)) {
    _serverResponse.status(HttpStatus.CONFLICT).send(
        "Bad Reqeust: The name $name is already taken");
    return false;
  }

  return true;
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
 * gets the User hash by name from the Memory
 * @return m, if user is found
 * @return Status 404 NOT_FOUND, if the user wasn't found
 */
Map get_user_by_name(String name, Map memory) {
  for (Map m in memory['users']) {
    if (m['name'] == name) return m;
  }
  _serverResponse.status(HttpStatus.NOT_FOUND).send(
      "User not Found.");
  return null;
}

/**
 * gets the User hash by name from the Memory
 * @return m, if user is found
 * @return Status 404 NOT_FOUND, if the user wasn't found
 */
Map get_user_by_id(String id, Map memory) {
  for (Map m in memory['users']) {
    if (m['id'].toString() == id.toString()) return m;
  }
  _serverResponse.status(HttpStatus.NOT_FOUND).send(
      "User not Found.");
  return null;
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

/**
 * Generates the Signature of a User or a Game with the parameters
 * @param id, of the User or the Game
 * @param passwordOrSecret, of the User or the Game
 *
 * @return signature
 */
String _generateSignature(String id, String passwordOrSecret) {
  return BASE64
      .encode(sha256.convert(UTF8.encode(id + "," + passwordOrSecret)).bytes);
}

/**
 * Authenticates a User or a Game with its ID and Password/Secret
 *
 * @return true, if the given credentials match with the ones saved
 * @return false, if the given credentials doesn't match with the ones saved
 */
bool _toAuthenticate(Map entity, String password) {
  if(entity['signature'] == _generateSignature(entity['id'].toString(), password))
    return true;
  return false;
}