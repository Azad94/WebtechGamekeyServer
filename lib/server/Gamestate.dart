part of serverLibrary;

class GameState{
  int _id;
  int _calendar;
  User _user;
  DateTime _createdAt = new DateTime.now();

  GameState(this._id, this._calendar, this._user, this._createdAt);
}