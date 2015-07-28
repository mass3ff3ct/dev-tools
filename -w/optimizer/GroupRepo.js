// Generated by CoffeeScript 1.8.0
var GroupRepo, OptimizerGroup;

OptimizerGroup = (function() {

  /*
  Simply little abstraction of module optimization group
   */
  OptimizerGroup.prototype._items = null;

  OptimizerGroup.prototype._modules = null;

  OptimizerGroup.prototype._subGroups = null;

  OptimizerGroup.prototype._isSubGroup = false;

  function OptimizerGroup(repo, id, items) {
    var group, item, _i, _len;
    this.repo = repo;
    this.id = id;

    /*
    @param OptimizerGroupRepo repo group repository (creator)
    @param String id group unique id
    @param Array[String] items list of modules and/or sub-group ids which belongs to this new group
     */
    this._items = items;
    this._modules = [];
    this._subGroups = [];
    for (_i = 0, _len = items.length; _i < _len; _i++) {
      item = items[_i];
      if (group = this.repo.getGroup(item)) {
        group.markAsSubGroup();
        this._subGroups.push(group);
        this._modules = this._modules.concat(group.getModules());
      } else {
        this._modules.push(item);
      }
    }
  }

  OptimizerGroup.prototype.getItems = function() {
    return this._items;
  };

  OptimizerGroup.prototype.getModules = function() {
    return this._modules;
  };

  OptimizerGroup.prototype.getSubGroups = function() {
    return this._subGroups;
  };

  OptimizerGroup.prototype.markAsSubGroup = function() {
    return this._isSubGroup = true;
  };

  OptimizerGroup.prototype.isSubGroup = function() {
    return this._isSubGroup;
  };

  return OptimizerGroup;

})();

GroupRepo = (function() {

  /*
  Global repository of optimization groups.
  Creates groups and contains key-value list of OptimizationGroup by their IDs.
   */
  GroupRepo.prototype._groups = null;

  function GroupRepo() {
    this._groups = {};
  }

  GroupRepo.prototype.createGroup = function(groupId, modules) {
    return this._groups[groupId] = new OptimizerGroup(this, groupId, modules);
  };

  GroupRepo.prototype.getGroup = function(groupId) {
    return this._groups[groupId];
  };

  GroupRepo.prototype.removeGroupDeep = function(groupId) {

    /*
    Removes the group with the given group id and all it's sub-groups from this group repository.
    Used to determine remaining unused groups.
    @param String groupId
     */
    var subGroup, _i, _len, _ref;
    if (this._groups[groupId]) {
      _ref = this._groups[groupId].getSubGroups();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        subGroup = _ref[_i];
        this.removeGroupDeep(subGroup.id);
      }
      return delete this._groups[groupId];
    }
  };

  GroupRepo.prototype.getGroups = function() {
    return this._groups;
  };

  return GroupRepo;

})();

module.exports = GroupRepo;
