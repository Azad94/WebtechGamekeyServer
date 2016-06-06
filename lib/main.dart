import 'dart:convert';
import 'dart:io' ;
import 'package:start/start.dart';
import 'dart:math';
import 'package:crypto/crypto.dart';

//Map _usermap = new Map<String, User>();
//Map _gameMap = new Map<String, Game>();
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

/// Enables Cross origin by editing the response header
void enableCors(Response response) {
  print("-------CORS HAS BEEN ENABLED----------");
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

///Gets game by id
///
/// returns null if game not found
Map get_game_by_id(String id, Map memory) {
  print("----- GET GAME BY ID -----");
  for (Map m in memory['games']) {
    if (m['id'].toString() == id.toString()) return m;
  }
  return null;
}

///Looks for existing game by id
///
/// returns false if not found
bool game_exists(String name, Map memory) {
  print("----- CHECK IF GAME EXISTS -----");
  for (Map m in memory['games']) {
    if (m['name'] == name) return true;
  }
  return false;
}

///Gets user by name
///
/// returns null if user not found
Map get_user_by_name(String name, Map memory) {
  print("----- GET USER BY NAME -----");
  for (Map m in memory['users']) {
    if (m['name'] == name) return m;
  }
}

///Gets user by id
///
/// returns null if user not found
Map get_user_by_id(String id, Map memory) {
  print("----- GET USER BY ID -----");
  for (Map m in memory['users']) {
    if (m['id'].toString() == id.toString()) return m;
  }
}

///Looks for existing user by id
///
/// returns false if not found
bool user_exists(String name, Map memory) {
  print("----- CHECK IF USER EXISTS -----");
  for (Map m in memory['users']) {
    if (m['name'] == name) return true;
  }
  return false;
}

///Control if E-Mail is correct
///
/// returns false if E-Mail has no Match with RegExp
bool isEmail(String em) {
  print("----- CHECK IF EMAIL IS CORRECT -----");
  String p = r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
  RegExp regExp = new RegExp(p);
  return regExp.hasMatch(em);
}

///Control if Url is correct
///
/// returns false if Url has no Match with RegExp
bool isUrl(String url) {
  print("----- CHECK IF URL IS CORRECT -----");
  String exp = r'(https?:\/\/)';
  RegExp regExp = new RegExp(exp);
  return regExp.hasMatch(url);
}

///Authentication
///
/// returns true if Authentication failed or false if Authentic
bool isNotAuthentic(Map map, String pwd) {
  print("----- CHECK IF IS AUTHENTIC -----");
  if (map["signature"] != BASE64.encode(
      (sha256.convert(UTF8.encode(map["id"].toString() + ',' + pwd.toString())))
          .bytes)) return true;
  return false;
}

main() async {

  ///Test if gamekey already hast data
  if (!await _serverStorage.exists() || (await _serverStorage.length() < _defaultData.length)) {
    _serverStorage.openWrite().write(JSON.encode(_defaultData));
  }

  ///initialize Memory with gamekey.json
  _gamekeyMemory = JSON.decode(await _serverStorage.readAsString());
  start(host: '0.0.0.0', port: 8080).then((Server app) {
    app.static('web');

    ///Gets Users
    ///
    /// returns all Users
    app.get('/users').listen((request) {
      Response res = request.response;
      enableCors(res);
      res.status(HttpStatus.OK).json(_gamekeyMemory["users"]);
    });

    ///Posts one User
    ///
    /// returns created User if succesful
    app.post('/user').listen((request) async {
      ///enabling cors
      Response res = request.response;
      enableCors(res);

      ///Parameters
      String name = request.param("name");
      String pwd = request.param("pwd");
      var mail = request.param("mail");
      var id = new Random.secure().nextInt(0xFFFFFFFF);

      ///Reading payload from request
      //Request req = request;
      if (request.input.headers.contentLength != -1) {
        var map = await request.payload();
        if (name.isEmpty) name = map["name"];
        if (pwd.isEmpty) pwd = map["pwd"];
        if (mail.isEmpty) mail = map["mail"];
      }

      ///Test if required params are given
      if (name == null || name.isEmpty) {
        res.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: Name is required");
        return null;
      }

      if (pwd == null) {
        res.status(HttpStatus.BAD_REQUEST).send(
            "Bad Request: Password is required");
        return null;
      }

      ///Test if Mail is valid
      if (mail != null) {
        if (!isEmail(mail)) {
          res.status(HttpStatus.BAD_REQUEST).send(
              "Bad Request: $mail is not a valid email.");
          return null;
        }
      }

      ///Test if user already exists
      if (user_exists(name, _gamekeyMemory)) {
        res.status(HttpStatus.CONFLICT).send(
            "Bad Reqeust: The name $name is already taken");
        return null;
      }

      ///creating user with parameters
      var user = {
        'type' : "user",
        'name' : name,
        'id' : id.toString(),
        'created' : (new DateTime.now().toUtc().toIso8601String()),
        'mail' : (mail != null) ? mail : '',
        'signature' : BASE64.encode(sha256
            .convert(UTF8.encode(id.toString() + ',' + pwd))
            .bytes)
      };
      _gamekeyMemory["users"].add(user);
      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      res.status(HttpStatus.OK).json(user);
    });

    ///Gets User by Id
    ///
    ///returns user if user exists
    app.get('/user/:id').listen((request) async {
      ///Enabling Cors
      Response res = request.response;
      enableCors(res);

      ///Initializing Params
      var id = request.param("id");
      var pwd = request.param("pwd");
      String byname = request.param("byname");
      if (request.input.headers.contentLength != -1) {
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
        //print("unauthorized");
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

    ///Puts user by id
    ///
    /// returns updated user if succesfull
    app.put('/user/:id').listen((request) async {
      ///Enabling Cors
      Response res = request.response;
      enableCors(res);

      ///Initializing params
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
      user['update'] = new DateTime.now().toUtc().toIso8601String();
      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      //Return edited User as Json
      res.status(HttpStatus.OK).json(user);
    });

    ///Delete for users by id
    ///
    /// returns Success if everything worked
    app.delete('/user/:id').listen((request) async {
      ///Enabling Cors
      Response res = request.response;
      enableCors(res);

      ///Initializing params
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
      res.status(HttpStatus.OK).send("Succes");
    });

    ///Gets all games
    ///
    /// Returns a list of all saved games as Json
    app.get('/games').listen((request) {
      Response res = request.response;
      enableCors(res);
      res.status(HttpStatus.OK).json(_gamekeyMemory['games']);
    });

    ///Post for games
    ///
    ///Creates a new game with given Parameters
    app.post('/game').listen((request) async {
      //Enabling Cors
      Response res = request.response;
      enableCors(res);
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
        "created" : new DateTime.now().toUtc().toIso8601String()
      };

      _gamekeyMemory['games'].add(game);
      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      res.status(HttpStatus.OK).json(game);
    });

    ///Gets a game by id
    ///
    ///Returns game if id and secret is correct
    app.get('/game/:id').listen((request) async {
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
      //Control if Signature matches input(has to be changed to isNotAuthentic)
      if (BASE64.encode(
          (sha256.convert(UTF8.encode(id.toString() + ',' + secret.toString())))
              .bytes) != game['signature']) {
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

    ///Edits a game
    ///
    ///returns edited game if succesfull
    app.put('/game/:id').listen((request) async {
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
        if (new_url.isEmpty) new_url = map["url"] == null ? "" : map["url"];
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
      if (isNotAuthentic(game,secret)) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }
      if (!new_name.isEmpty) game['name'] = new_name;
      //Url cant be deleted
      if (!new_url.isEmpty) game['url'] = new_url;
      //new_secret cant be empty string
      if (!new_secret.isEmpty) game['signature'] = BASE64.encode((sha256.convert(
          UTF8.encode(id.toString() + ',' + new_secret.toString()))).bytes);
      game['update'] = new DateTime.now().toUtc().toString();
      _serverStorage.openWrite().write(JSON.encode(_gamekeyMemory));
      res.status(HttpStatus.OK).json(game);
    });

    ///Deletes game by id
    ///
    ///returns Success if game is deleted or not existent
    app.delete('/game/:id').listen((request) async {
      //Enabling Cors
      Response res = request.response;
      enableCors(res);
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
        res.status(HttpStatus.OK).send("Game not found");
        return null;
      }
      //Control if isAuthentic(should be changed to function)
      if (BASE64.encode(
          (sha256.convert(UTF8.encode(id.toString() + ',' + secret.toString())))
              .bytes) != game['signature']) {
        res.status(HttpStatus.UNAUTHORIZED).send(
            "unauthorized, please provide correct credentials");
        return null;
      }

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

    ///Gets gamestates from Specific user and game
    ///
    ///
    app.get('/gamestate/:gameid/:userid').listen((request) async {
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

      //Control if is Authentic
      if (isNotAuthentic(game,secret)) {
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
      res.status(HttpStatus.OK).json(states);
    });

    ///Gets all gamestates of game by id
    ///
    ///Returns List of all gamestates from game if successfull
    app.get('/gamestate/:gameid').listen((request) async {
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

      //Control if isAuthentic
      if (isNotAuthentic(game,secret)) {
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

    ///Post for gamestates
    ///
    ///returns Gamestate if successfull
    app.post('/gamestate/:gameid/:userid').listen((request) async {
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

      //Control if isAuthentic
      if (isNotAuthentic(game,secret)) {
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