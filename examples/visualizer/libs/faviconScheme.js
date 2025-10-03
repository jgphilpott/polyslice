// Credit: https://stackoverflow.com/a/55252008/1544937

var darkSchemeIcon, lightSchemeIcon, schemeMatcher, schemeUpdate

lightSchemeIcon = document.querySelector("link#light-scheme-icon")
darkSchemeIcon = document.querySelector("link#dark-scheme-icon")

schemeMatcher = window.matchMedia("(prefers-color-scheme: light)")

schemeUpdate = function() {
  if (schemeMatcher.matches) {
    document.head.append(lightSchemeIcon)
    return darkSchemeIcon.remove()
  } else {
    document.head.append(darkSchemeIcon)
    return lightSchemeIcon.remove()
  }
};

schemeMatcher.addListener(schemeUpdate)

schemeUpdate()