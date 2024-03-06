// Generated by CoffeeScript 2.7.0
var localDelete, localDump, localKeys, localRead, localWrite

localKeys = function() {
  return Object.keys(window.localStorage)
}

localWrite = function(key, value) {
  var error
  try {
    window.localStorage.setItem(String(key), JSON.stringify(value))
    return true
  } catch (error1) {
    error = error1
    return false
  }
}

localRead = function(key) {
  var error
  try {
    return JSON.parse(window.localStorage.getItem(String(key)))
  } catch (error1) {
    error = error1
    return null
  }
}

localDelete = function(key) {
  var error
  try {
    window.localStorage.removeItem(String(key))
    return true
  } catch (error1) {
    error = error1
    return false
  }
}

localDump = function() {
  return window.localStorage.clear()
}