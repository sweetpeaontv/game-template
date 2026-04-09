extends Node

# this probably doesn't need to be an autoload
# but it's a good place to put it for now
var interactables: Registry = Registry.new()
var operables: Registry = Registry.new()
var pickupables: Registry = Registry.new()
var examinables: Registry = Registry.new()