part of serverLibrary;

class Game{
  String _id;
  String _name;
  String _url;
  String _signature;
  DateTime _createdAt = new DateTime.now();
  List<GameState> _gameStateListe;

  Game(this._id, this._name, this._url, this._signature, this._createdAt,
      this._gameStateListe);
}