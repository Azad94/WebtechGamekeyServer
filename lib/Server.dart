import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:start/start.dart';
import 'package:crypto/crypto.dart';

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
  if (!await _serverCache.exists()
      || (await _serverCache.length() < _defaultData.length)) {
    _serverCache.openWrite().write(JSON.encode(_defaultData));
  }
  /**
   * write the existing data into the _runtimeMemory
   */
  _runtimeMemory = JSON.decode(await _serverCache.readAsString());

  /**
   * Initializes the server on Localhost and on the given Port
   */
  start(host: '0.0.0.0', port: 6060).then((Server _gamekeyServer) {
    _gamekeyServer.static('web');

    /**
     *
     *
     *                The Options API for all Possible Methods begins HERE.
     *
     *
     */

    /**
     * handles the OPTIONS USERS request
     *
     * Sends the Information to the Client, which Methods
     * the server handles on Users.
     *
     * @return  response includes Methods allowed for Users
     */
    _gamekeyServer.options('/users').listen((request) {
      _serverResponse = request.response;
      enableCors(_serverResponse);
      _serverResponse.send("POST, GET, GET/:Id, PUT/:Id, DELETE/:Id");
    });

    /**
     * handles the OPTIONS GAMES Request
     *
     * Sends the Information to the Client, which Methods
     * the server handles on Games.
     *
     * @return  response includes Methods allowed for Games
     */
    _gamekeyServer.options('/games').listen((request) {
      _serverResponse = request.response;
      enableCors(_serverResponse);
      _serverResponse.send("POST, GET, GET/:Id, PUT/:Id, DELETE/:Id");
    });

    /**
     * handles the OPTIONS GAMESTATES Request
     *
     * Sends the Information to the Client, which Methods
     * the server handles on Gamestates.
     *
     * @return  response includes Methodes allowed for Gamestates
     */
    _gamekeyServer.options('/gamestates').listen((request) {
      _serverResponse = request.response;
      enableCors(_serverResponse);
      _serverResponse.send("POST/:Gameid/:Userid, GET/:Gameid, GET/:Gameid/:Userid");
    });





    /**
     *
     *
     *                The API for the User begins HERE.
     *
     *
     */

    /**
     * handles the GET USERS request
     *
     * Retrieves all registered User on the GamekeyServer.
     *
     * @return 200 OK,          response includes all the registered Users
     */
    _gamekeyServer.get('/users').listen((request) {
      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * respond for the Client contains a List of all registered Users
       */
      _serverResponse.status(HttpStatus.OK).json(_runtimeMemory["users"]);
    });

    /**
     * handles the POST USER Request
     *
     * Posts a User on the GameKeyServer with the required
     * parameters
     *
     * @param name,             Name of the User.
     * @param pwd,              Password of the User, which is used for the
     *                          authentication.
     * @param mail,             Mail of the User (is optional).
     *
     * @return 200 OK,          if the User the was created successfully
     * @return 400 BAD_REQUEST, if any of the param is null, empty
     *                          or not acceptable
     * @return 409 CONFLICT,    if the User already exists
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
          var map = await _clientRequest.payload();
          if (_userName.isEmpty) _userName = map["name"];
          if (_userPwd.isEmpty) _userPwd = map["pwd"];
          if (_userMail.isEmpty) _userMail = map["mail"];
        }

        if (!_validateUserParams(_serverResponse ,_userName,
            _userPwd, _userMail))
          return null;

        /**
         * creates the User after validation which is
         * supposed to be added
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
         * adds the User to the runtime Memory
         */
        _runtimeMemory["users"].add(user);

        /**
         * updates the server File
         */
        _serverCache.openWrite().write(JSON.encode(_runtimeMemory));

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
     * @param id,                 Id of the User.
     * @param pwd,                Password of the User, which is used for the
     *                            authentication.
     *
     * @return 200 OK,            if the User was found
     * @return 400 BAD_REQUEST,   if any of the param is null, empty
     *                            or not acceptable
     * @return 401 UNAUTHORIZED,  if the credentials are wrong
     * @return 404 NOT_FOUND,     if the User doesn't exist
     */
    _gamekeyServer.get('/user/:id').listen((request) async {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * the User that is being searched
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
      if (!(_userByname.isEmpty) && (_userByname != 'true')
          && (_userByname != 'false')) {
        _serverResponse.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: byname parameter must be 'true' or 'false' "
                "(if set), was $_userByname.");
        return null;
      }

      if (_userByname == 'true')
        _searchedUser = get_user_by_name(id, _runtimeMemory);

      if (_userByname == 'false' || _userByname.isEmpty)
        _searchedUser = get_user_by_id(id, _runtimeMemory);

      if (_searchedUser == null){
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

      /**
       * Duplicates the User and adds all its games and gamestates
       */
      _searchedUser = new Map.from(_searchedUser);
      _searchedUser['games'] = new List();
      if (_runtimeMemory['gamestates'] != null) {
        for (Map m in _runtimeMemory['gamestates']) {
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
     * handles the PUT USER ID request
     *
     * Updates a User.
     *
     * @param _currentId,         Current Id of the User, which is supposed to
     *                            be updated
     * @param _currentPwd,        Current Password of the User, which is
     *                            supposed to be deleted
     * @param _newUserName,       Name of the User is changed, according to the
     *                            new given User name
     * @param _newUserMail,       Mail of the User is changed, according to the
     *                            new given User mail
     * @param _newUserPwd,        Regenerates the password of the User
     *
     * @return 200 OK,            if the User was updates successfully
     * @return 400 BAD_REQUEST,   if the Mail is not allowed
     * @return 401 UNAUTHORIZED   if the credentials are wrong
     * @return 409 CONFLICT       if the User already exists
     */
    _gamekeyServer.put('/user/:id').listen((request) async {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * retrieves the parameters from the
       * Client request
       */
      String _currentId = request.param("id");
      String _currentPwd = request.param("pwd");
      String _newUserName = request.param("name");
      String _newUserMail = request.param("mail");
      String _newUserPwd = request.param("newpwd");

      /**
       * retrieves the parameters from the
       * payload of the Client request
       */
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (_currentPwd.isEmpty) _currentPwd = map["pwd"] == null ? ""
            : map["pwd"];

        if (_newUserName.isEmpty) _newUserName = map["name"] == null ? ""
            : map["name"];

        if (_newUserMail.isEmpty) _newUserMail = map["mail"] == null ? ""
            : map["mail"];

        if (_newUserPwd.isEmpty)
          _newUserPwd = map["newpwd"] == null ? "" : map["newpwd"];
      }

      //checks if the given E-Mail is allowed
      if (!isEmail(_newUserMail) && !_newUserMail.isEmpty) {
        _serverResponse.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: $_newUserMail is not a valid email.");
        return null;
      }

      //checks if the User already exists
      if (user_exists(_newUserName, _runtimeMemory)) {
        _serverResponse.status(HttpStatus.CONFLICT).send(
            "User with name $_newUserName exists already.");
        return null;
      }
      //Reads user which has to be edited
      var user = get_user_by_id(_currentId, _runtimeMemory);

      if (!_toAuthenticate(user, _currentPwd)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      /**
       * sets the new credentials and information of a User
       */
      if (!_newUserName.isEmpty) user['name'] = _newUserName;
      if (!_newUserMail.isEmpty) user['mail'] = _newUserMail;
      if (_newUserPwd != null || !_newUserPwd.isEmpty) user['signature'] =
          _generateSignature(_currentId.toString(), _newUserPwd);
      user['update'] = new DateTime.now().toUtc().toIso8601String();

      /**
       * updates the server File
       */
      _serverCache.openWrite().write(JSON.encode(_runtimeMemory));

      /**
       * respond for the Client contains the updated User
       */
      _serverResponse.status(HttpStatus.OK).json(user);
    });

    /**
     * handles the DELETE USER ID request
     *
     * Deletes the User with the given ID and all of its associated game states.
     *
     * @param _userId,            Current Id of the User which is supposed to
     *                            be deleted
     * @param _userPwd,           Current Password of the User, which is
     *                            supposed to be deleted
     *
     * @return 200 OK,            if the User was deleted successfully (even
     *                            if the given User is null)
     * @return 401 UNAUTHORIZED   if the credentials are wrong
     */
    _gamekeyServer.delete('/user/:id').listen((request) async {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * retrieves the parameters from the
       * Client request
       */
      var _userId = request.param("id");
      var _userPwd = request.param("pwd");

      /**
       * retrieves the parameters from the
       * payload of the Client request
       */
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        _userPwd = map["pwd"] == null ? "" : map["pwd"];
      }

      //Gets the User which is supposed to be deleted
      var user = get_user_by_id(_userId, _runtimeMemory);

      //even if User is null send OK Status
      if (user == null) {
        _serverResponse.status(HttpStatus.OK).send(
            "User not found.");
        return null;
      }

      if (!_toAuthenticate(user, _userPwd)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      //Deletes the User from the server memory
      if (_runtimeMemory['users'].remove(user) == null) {
        _serverResponse.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .send('Failed\n$user');
      }

      //Deletes the Game states belonging to that specific User
      List<Map> _deleteGamestates = new List<Map>();
      _runtimeMemory['gamestates']
          .where((_gamestate) => _gamestate["userid"].toString()
              == _userId.toString())
          .forEach((_gamestate) => _deleteGamestates.add(_gamestate));
      _deleteGamestates.forEach((_gamestate) =>
          _runtimeMemory["gamestates"].remove(_gamestate));

      /**
       * updates the server File
       */
      _serverCache.openWrite().write(JSON.encode(_runtimeMemory));

      /**
       * respond for the Client contains the Success message
       */
      _serverResponse.status(HttpStatus.OK).send("Success");
    });


    /**
     *
     *
     *                The API for the Game begins HERE.
     *
     *
     */


    /**
     * handles the GET GAMES request
     *
     * Lists all the registered games on the server.
     *
     * @return 200 OK,  send a list of all registered games
     */
    _gamekeyServer.get('/games').listen((request) {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * respond for the Client contains a list of all registered Games
       */
      _serverResponse.status(HttpStatus.OK).json(_runtimeMemory['games']);
    });

    /**
     * handles the POST GAME Request
     *
     * Posts a Game on the GameKeyServer with the required parameters
     *
     * @param _gameName,        Name of the Game
     * @param _gameSecret,      Secret of the Game, which is used for the
     *                          authentication.
     * @game _gameUrl,           Url of the Game
     *
     * @return 200 OK,          if the Game was created successfully
     * @return 400 BAD_REQUEST, if any of the param is null, empty
     *                          or not acceptable
     * @return 409 CONFLICT,    if the Game already exists
     */
    _gamekeyServer.post('/game').listen((request) async {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * retrieves the parameters from the
       * Client request
       */
      String _gameName = request.param('name');
      var _gameSecret = request.param('secret');
      String _gameUrl = request.param('url');

      /**
       * retrieves the parameters from the
       * payload of the Client request
       */
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (_gameName.isEmpty) _gameName = map["name"] == null ? ""
            : map["name"];

        if (_gameSecret.isEmpty) _gameSecret = map["secret"] == null ? ""
            : map["secret"];

        if (_gameUrl.isEmpty) _gameUrl = map["url"] == null ? "" : map["url"];
      }

      var id = new Random.secure().nextInt(0xFFFFFFFF);

      //Check if the given URL is valid
      Uri uri = Uri.parse(_gameUrl);
      if (uri != null || !_gameUrl.isEmpty) {
        if (uri.isAbsolute) {
          _serverResponse.status(HttpStatus.BAD_REQUEST)
              .send("Bad Request: '" + _gameUrl + "' is not a "
                "valid absolute url");
          return null;
        }
      }

      if(!_validateGameParams(_serverResponse, _gameName,
            _gameSecret, _gameUrl)){
        return null;
      }

      /**
       * creates the Game, after validation, which is
       * supposed to be added
       */
      Map game = {
        "type" : 'game',
        "name" : _gameName,
        "id" : id.toString(),
        "url" : uri.toString(),
        "signature" : BASE64.encode((sha256.convert(
            UTF8.encode(id.toString() + ',' + _gameSecret.toString()))).bytes),
        "created" : new DateTime.now().toUtc().toIso8601String()
      };

      /**
       * adds the Game to the runtime Memory
       */
      _runtimeMemory['games'].add(game);

      /**
       * updates the server File
       */
      _serverCache.openWrite().write(JSON.encode(_runtimeMemory));

      /**
       * respond for the Client contains the created Game
       */
      _serverResponse.status(HttpStatus.OK).json(game);
    });

    /**
     * handles the GET GAME / ID Request
     *
     * Retrieves the Game which is searched for.
     *
     * @param _gameId,            Id of the Game
     * @param _gameSecret,        Secret of the Game, which is used for the
     *                            authentication
     *
     * @return 200 OK,            if the Game was found
     * @return 401 UNAUTHORIZED,  if the credentials are wrong
     * @return 404 NOT_FOUND,     if the Game doesn't exist
     */
    _gamekeyServer.get('/game/:id').listen((request) async {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * retrieves the parameters from the
       * Client request
       */
      var _gameId = request.param('id');
      var _gameSecret = request.param('secret');

      /**
       * retrieves the parameters from the
       * payload of the Client request
       */
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (_gameSecret.isEmpty) _gameSecret = map["secret"] == null ? ""
            : map["secret"];
      }

      var game = get_game_by_id(_gameId, _runtimeMemory);

      if (game == null) {
        _serverResponse.status(HttpStatus.NOT_FOUND).send("Game not found");
        return null;
      }

      if (!_toAuthenticate(game, _gameSecret)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      //Duplicates a game and adds the List of Users to it
      game = new Map.from(game);
      game['users'] = new List();
      if (_runtimeMemory['gamestates'] != null) {
        for (Map m in _runtimeMemory['gamestates']) {
          if (m['gameid'].toString() == _gameId.toString()) {
            game['users'].add(m['userid']);
          }
        }
      }

      /**
       * respond for the Client contains the searched Game
       */
      _serverResponse.status(HttpStatus.OK).json(game);
    });

    /**
     * handles the PUT GAME / ID request
     *
     * Updates a Game.
     *
     * @param _currentId,         Current Id of the Game, which is supposed to
     *                            be updated
     * @param _currentSecret,     Current Secret of the Game, which is
     *                            supposed to be deleted
     * @param _newGameName,       Name of the Game is changed, according to the
     *                            new given Game name
     * @param _newGameUrl,        Url of the Game is changed, according to the
     *                            new given Game url
     * @param _newGamePwd,        Regenerates the password of the Game
     *
     * @return 200 OK,            if the Game was updates successfully
     * @return 400 BAD_REQUEST,   if the URL is not allowed
     * @return 401 UNAUTHORIZED   if the credentials are wrong
     * @return 409 CONFLICT       if the Game already exists
     */
    _gamekeyServer.put('/game/:id').listen((request) async {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * retrieves the parameters from the
       * Client request
       */
      var _currentGameId = request.param('id');
      var _currentSecret = request.param('secret');
      var _newGameName = request.param('name');
      var _newGameUrl = request.param('url');
      var _newGameSecret = request.param('secret');

      /**
       * retrieves the parameters from the
       * payload of the Client request
       */
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (_newGameName.isEmpty) _newGameName = map["name"] == null ? ""
            : map["name"];

        if (_currentSecret.isEmpty) _currentSecret = map["secret"] == null ? ""
            : map["secret"];

        if (_newGameUrl.isEmpty) _newGameUrl = map["url"] == null ? ""
            : map["url"];

        if (_newGameSecret.isEmpty)
          _newGameSecret = map["newsecret"] == null ? "" : map["newsecret"];
      }

      var game = get_game_by_id(_currentGameId, _runtimeMemory);

      //Check if the given URL is valid
      if (!_newGameUrl.isEmpty && (!isUrl(_newGameUrl))) {
        _serverResponse.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: '" + _newGameUrl + "' is not a valid absolute url");
        return null;
      }
      //Control if the Game already exists
      if (!_newGameName.isEmpty) {
        if (game_exists(_newGameName, _runtimeMemory)) {
          _serverResponse.status(HttpStatus.CONFLICT).send(
              "Game Already exists");
          return null;
        }
      }

      if (!_toAuthenticate(game, _currentSecret)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      /**
       * sets the new credentials and information of a Game
       */
      if (!_newGameName.isEmpty) game['name'] = _newGameName;
      if (!_newGameUrl.isEmpty) game['url'] = _newGameUrl;
      if (!_newGameSecret.isEmpty) game['signature'] =
          _generateSignature(_currentGameId.toString(), _newGameSecret);
      game['update'] = new DateTime.now().toString();

      /**
       * updates the server File
       */
      _serverCache.openWrite().write(JSON.encode(_runtimeMemory));

      /**
       * respond for the Client contains the updated Game
       */
      _serverResponse.status(HttpStatus.OK).json(game);
    });

    /**
     * handles the DELETE GAME / ID request
     *
     * Deletes the Game with the given ID and all of its associated game states.
     *
     * @param _gameId,            Id of the Game which is supposed to
     *                            be deleted
     * @param _gameSecret,        Secret of the User, which is
     *                            supposed to be deleted
     *
     * @return 200 OK,            if the Game was deleted successfully (even
     *                            if the given Game is null)
     * @return 401 UNAUTHORIZED   if the credentials are wrong
     */
    _gamekeyServer.delete('/game/:id').listen((request) async {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * retrieves the parameters from the
       * Client request
       */
      var _gameId = request.param('id');
      var _gameSecret = request.param('secret');

      /**
       * retrieves the parameters from the
       * payload of the Client request
       */
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (_gameSecret.isEmpty) _gameSecret = map["secret"] == null ? ""
            : map["secret"];
      }

      var game = get_game_by_id(_gameId, _runtimeMemory);

      if (game == null) {
        _serverResponse.status(HttpStatus.OK).send("Game not found");
        return null;
      }

      if (!_toAuthenticate(game, _gameSecret)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      //Deletes the Game from the server memory
      if (_runtimeMemory['games'].remove(game) == null) {
        _serverResponse.status(HttpStatus.OK)
            .send('Game $_gameId deleted successfully.');
      }

      //Removes all gamestates of the Game to be deleted
      List<Map> _deleteGameStates = new List<Map>();
      _runtimeMemory['gamestates']
          .where((_gamestate) => _gamestate["gameid"].toString()
              == _gameId.toString())
          .forEach((_gamestate) => _deleteGameStates.add(_gamestate));
      _deleteGameStates.forEach((_gamestate) =>
          _runtimeMemory["gamestates"].remove(_gamestate));

      /**
       * updates the server File
       */
      _serverCache.openWrite().write(JSON.encode(_runtimeMemory));

      /**
       * respond for the Client contains the Success message
       */
      _serverResponse.status(HttpStatus.OK).send('Success');
    });


    /**
     *
     *
     *                The API for the Gamestate begins HERE.
     *
     *
     */


    /**
     * handles the GET GAMESTATE / GAME_ID / USER_ID Request
     *
     * Retrieves all gamestates stored for a specific Game and user.
     * The Gamestates are sorted by decreasing creation timestamps.
     *
     * @param _userId,            Id of the User
     * @param _gameId,            Id of the Game
     * @param _gameSecret,        Secret of the Game, which is used for the
     *                            authentication
     *
     * @return 200 OK,            if the Game was found
     * @return 401 UNAUTHORIZED,  if the credentials are wrong
     * @return 404 NOT_FOUND,     if gamestates are not found due to wrong
     *                            _userId or _gameId
     */
    _gamekeyServer.get('/gamestate/:gameid/:userid').listen((request) async {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * retrieves the parameters from the
       * Client request
       */
      var _userId = request.param("userid");
      var _gameId = request.param("gameid");
      var _gameSecret = request.param("secret");

      /**
       * retrieves the parameters from the
       * payload of the Client request
       */
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (_gameSecret.isEmpty) _gameSecret = map["secret"] == null ? ""
            : map["secret"];
      }

      var _game = get_game_by_id(_gameId, _runtimeMemory);
      var _user = get_user_by_id(_userId, _runtimeMemory);


      if (_user == null || _game == null) {
        _serverResponse.status(HttpStatus.NOT_FOUND).send(
            "User or game NOT Found.");
        return null;
      }

      if (!_toAuthenticate(_game, _gameSecret)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      var _gamestates = new List<Map>();
      for (Map _map in _runtimeMemory['gamestates']) {
        if (_map['gameid'].toString() == _gameId.toString() &&
            _map['userid'].toString() == _userId.toString()) {
          var _gamestate = new Map.from(_map);
          _gamestate["gamename"] = _game["name"];
          _gamestate["username"] = _user["name"];
          _gamestates.add(_gamestate);
        }
      }

      //Sorts the Gamestates in order of Creation
      _gamestates.sort((a, s) =>
          DateTime.parse(s["created"]).compareTo(DateTime.parse(a["created"])));

      /**
       * respond for the Client contains a list of all Gamestates
       * of a Game and User
       */
      _serverResponse.status(HttpStatus.OK).json(_gamestates);
    });

    /**
     * handles the GET GAMESTATE / GAME_ID Request
     *
     * Retrieves all gamestates stored for a specific Game.
     * The Gamestates are sorted by decreasing creation timestamps.
     *
     * @param _gameId,            Id of the Game
     * @param _gameSecret,        Secret of the Game, which is used for the
     *                            authentication
     *
     * @return 200 OK,            if the Game was found
     * @return 401 UNAUTHORIZED,  if the credentials are wrong
     * @return 404 NOT_FOUND,     if gamestates are not found due to wrong
     *                            _gameId
     */
    _gamekeyServer.get('/gamestate/:gameid').listen((request) async {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * retrieves the parameters from the
       * Client request
       */
      var gameid = request.param('gameid');
      var secret = request.param('secret');

      /**
       * retrieves the parameters from the
       * payload of the Client request
       */
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (secret.isEmpty) secret = map["secret"] == null ? "" : map["secret"];
      }

      var game = get_game_by_id(gameid, _runtimeMemory);

      if (game == null) {
        _serverResponse.status(HttpStatus.NOT_FOUND).send(
            "Game NOT Found.");
        return null;
      }

      if (!_toAuthenticate(game, secret)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      //List all gamestates of a Game
      var _listGamestates = new List();
      for (Map _map in _runtimeMemory['gamestates']) {
        if (_map['gameid'].toString() == gameid.toString()) {
          var _gamestate = new Map.from(_map);
          _gamestate["gamename"] = game["name"];
          _gamestate["username"]
            = get_user_by_id(_map["userid"],_runtimeMemory);
          _listGamestates.add(_gamestate);
        }
      }

      /**
       * respond for the Client contains a list of all Gamestates
       * of a Game
       */
      _serverResponse.status(HttpStatus.OK).json(_listGamestates);
    });

    /**
     * handles the POST GAMESTATE Request
     *
     * Posts a Gamestate on the GameKeyServer with the required parameters
     *
     * @param _gameId,          Id of the Game
     * @param _userId,          Id of the User
     * @param _gameSecret,      Secret of the Game, which is used for the
     *                          authentication
     * @param _gamestate,       Gamestate to store
     *
     * @return 200 OK,          if the Gamestate was created successfully
     * @return 400 BAD_REQUEST, if the Gamstate was not encoded as valid JSON
     *                          or it was empty
     * @return 404 NOT FOUND,   if the _userId or the _gameId doesn't exist
     */
    _gamekeyServer.post('/gamestate/:gameid/:userid').listen((request) async {

      _serverResponse = request.response;
      enableCors(_serverResponse);

      /**
       * retrieves the parameters from the
       * Client request
       */
      var _gameId = request.param('gameid');
      var _userId = request.param('userid');
      var _gameSecret = request.param('secret');
      var _gamestate = request.param('state');

      /**
       * retrieves the parameters from the
       * payload of the Client request
       */
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (_gameSecret.isEmpty) _gameSecret = map["secret"] == null ? ""
            : map["secret"];

        if (_gamestate.isEmpty) _gamestate = map["state"] == null ? ""
            : map["state"];
      }

      var game = get_game_by_id(_gameId, _runtimeMemory);
      var user = get_user_by_id(_userId, _runtimeMemory);

      if (user == null || game == null) {
        _serverResponse.status(HttpStatus.NOT_FOUND).send(
            "User or game NOT Found.");
        return null;
      }

      if (!_toAuthenticate(game, _gameSecret)) {
        _serverResponse.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

      try {
        _gamestate = JSON.decode(_gamestate);

        if (_gamestate == null || _gamestate
            .toString()
            .isEmpty) {
          request.response.status(HttpStatus.BAD_REQUEST).send(
              "Bad request: state must not be empty, was $_gamestate");
          return null;
        }

        //Creates new Gamestate
        var _newGamestate = {
          "type" : 'gamestate',
          "gameid" : _gameId,
          "userid" : _userId,
          "created" : (new DateTime.now().toUtc().toIso8601String()),
          "state" : _gamestate
        };

        /**
         * adds the Gamestate to the runtime Memory
         */
        _runtimeMemory["gamestates"].add(_newGamestate);

        /**
         * updates the server File
         */
        _serverCache.openWrite().write(JSON.encode(_runtimeMemory));

        /**
         * respond for the Client contains the new Gamestate
         */
        _serverResponse.status(HttpStatus.OK).json(_newGamestate);

      } on NoSuchMethodError catch (e) {
        print(e);
        _serverResponse.status(HttpStatus.BAD_REQUEST)
            .send('Bad request: state must be provided as valid JSON, '
              'was $_gamestate');
      }
    });
  });
}

    /**
    *
    *
    *                Helper Methods, for the Restful Api Implementation.
    *
    *
    */

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
 * used for saving the data
 * during the runtime
 */
Map _runtimeMemory;

/**
 * saves the information of the server
 * till the next session of usage
 */
File _serverCache = new File('\serverCache.json');

/**
 * response which is going to be
 * send to the client according
 * to the request received
 */
Response _serverResponse;

/**
 * Get User by Name from Memory
 *
 * @return null, if User doesn't exist
 */
Map get_user_by_name(String name, Map memory) {

  for (Map _map in memory['users']) {
    if (_map['name'] == name) return _map;
  }
  return null;
}

/**
 * Get User by Id from Memory
 *
 * @return null, if User doesn't exist
 */
Map get_user_by_id(String id, Map memory) {

  for (Map _map in memory['users']) {
    if (_map['id'].toString() == id.toString())
      return _map;
  }
  return null;
}

/**
 * Check if User exists in the Memory
 *
 * @return false, if User doesn't exist
 */
bool user_exists(String name, Map memory) {

  for (Map _map in memory['users']) {
    if (_map['name'] == name) return true;
  }
  return false;
}

/**
 * Validate if the E-Mail is correct
 *
 * @return true, if mail is null or doesn't contain any characters
 */
bool isEmail(String mail) {

  String _mailRegex =
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\['
      r'[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+'
      r'\.)+[a-zA-Z]{2,}))$';

  RegExp _regexExpr = new RegExp(_mailRegex);
  if (mail == null || mail.length == 0)
    return true;
  return _regexExpr.hasMatch(mail);
}


/**
 * Get Game by Id from Memory
 *
 * @return null, if Game doesn't exist
 */
Map get_game_by_id(String id, Map memory) {
  for (Map _map in memory['games']) {
    if (_map['id'].toString() == id.toString())
      return _map;
  }
  return null;
}

/**
 * Check if Game exists in the Memory
 *
 * @return false, if Game doesn't exist
 */
bool game_exists(String name, Map memory) {
  for (Map _map in memory['games']) {
    if (_map['name'] == name) return true;
  }
  return false;
}

/**
 * Validate if the Url is correct
 *
 * @return Expression, if the Url is correct
 */
bool isUrl(String url) {
  String exp = r'(https?:\/\/)';
  RegExp _regexExp = new RegExp(exp);
  return _regexExp.hasMatch(url);
}


/**
 * Sets CORS headers for responses.
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
 * Generates the Signature for a User/Game
 * with the User_Id/Game_Id and the User_Pwd/Game_Secret
 *
 * @return signature
 */
String _generateSignature(String id, String password) {
  return BASE64
      .encode(sha256.convert(UTF8.encode(id + "," + password)).bytes);
}

/**
 * Authenticates a User/Game with it's credentials and
 * the related signature
 *
 * @return true, if generated credentials match the signature
 */
bool _toAuthenticate(Map entity, String password) {
  if(entity['signature'] ==
      _generateSignature(entity['id'].toString(), password))
    return true;
  return false;
}

/**
 * checks if the User parameters given are valid
 *
 * @return false & send 400 BAD_REQUEST,  if any of the params is null or empty
 * @return false & send 409 CONFLICT,     if the user already exists
 * @return true                           if all the params are valid
 */
bool _validateUserParams(Response _serverResponse, String _userName,
    String _userPwd, String _userMail){

  /**
   * validate User name
   *
   * @return false & 400 Bad Request  if _username is null or empty
   */
  if (_userName == null || _userName.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Name is required");
    return false;
  }

  /**
   * validate User password
   *
   * @return false & 400 BAD_REQUEST    if _userPwd is null or empty
   */
  if (_userPwd == null || _userPwd.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Password is required");
    return false;
  }

  /**
   *  validate User e-mail
   *
   *  @returns false & 400 BAD_REQUEST   if _usermail is not valid
   */
  if(_userMail != null){
    if (!isEmail(_userMail)) {
      _serverResponse.status(HttpStatus.BAD_REQUEST).send(
          "Bad Request: $_userMail is not a valid email.");
      return false;
    }
  }

  /**
   * check if the User already exists
   *
   * @return false & 409 CONFLICT   if User already exists
   */
  if (user_exists(_userName, _runtimeMemory)) {
    _serverResponse.status(HttpStatus.CONFLICT).send(
        "Bad Reqeust: The name $_userName is already taken");
    return false;
  }
  return true;
}


/**
 * checks if the Game parameters given are valid
 *
 * @return false & send 400 BAD_REQUEST,  if any of the params is null or empty
 * @return false & send 409 CONFLICT,     if the Game already exists
 * @return true                           if all the params are valid
 */
bool _validateGameParams(Response _serverResponse, String _gameName,
    String _gamePwd, String _gameUrl){

  /**
   * validate Game name
   *
   * @return false & 409 CONFLICT   if _gameName is null or empty
   */
  if (_gameName == null || _gameName.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Name is required");
    return false;
  }

  /**
   * validate Game password
   *
   * @return false & 400 BAD_REQUEST    if _gamePwd is null or empty
   */
  if (_gamePwd == null || _gamePwd.isEmpty) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: Password is required");
    return false;
  }

  /**
   * validate Game url
   *
   * @returns false & 400 BAD_REQUEST    if _gameUrl is not valid
   */
  if (!_gameUrl.isEmpty && !isUrl(_gameUrl)) {
    _serverResponse.status(HttpStatus.BAD_REQUEST).send(
        "Bad Request: '" + _gameUrl + "' is not a valid absolute url");
    return null;
  }

  /**
   * check if the Game already exists
   *
   * @return false & 409 CONFLICT   if Game already exists
   */
  if (game_exists(_gameName, _runtimeMemory)) {
    _serverResponse.status(HttpStatus.CONFLICT).send(
        "Bad Reqeust: The name $_gameName is already taken");
    return false;
  }
  return true;
}