var bactrianize, camelize, capitalize, dromedize, kebabify, lower, pascalize, snakify, titlize, upper;

lower = function(string) {
  return string.toLowerCase().trim();
};

upper = function(string) {
  return string.toUpperCase().trim();
};

// Credit: https://stackoverflow.com/a/1026087/1544937
capitalize = function(string) {
  return upper(string.trim().charAt(0)) + lower(string).slice(1);
};

// Credit: https://stackoverflow.com/a/52551910/1544937
camelize = function(string) {
  return lower(string).replace(/[^a-zA-Z0-9]+(.)/g, function(match, char) {
    return upper(char);
  });
};

// Credit: https://stackoverflow.com/a/52551910/1544937
pascalize = function(string) {
  return (" " + lower(string)).replace(/[^a-zA-Z0-9]+(.)/g, function(match, char) {
    return upper(char);
  });
};

// Credit: https://stackoverflow.com/a/52964182/1544937
snakify = function(string) {
  return string.trim().replace(/\W+/g, " ").split(/ |\B(?=[A-Z])/).map(function(word) {
    return lower(word);
  }).join("_");
};

// Credit: https://stackoverflow.com/a/52964182/1544937
kebabify = function(string) {
  return string.trim().replace(/\W+/g, " ").split(/ |\B(?=[A-Z])/).map(function(word) {
    return lower(word);
  }).join("-");
};

// Credit: https://stackoverflow.com/a/52551910/1544937
titlize = function(string) {
  return upper(string.trim().charAt(0)) + lower(string).replace(/[^a-zA-Z0-9]+(.)/g, function(match, char) {
    return " " + upper(char);
  }).slice(1);
};

// Credit: https://www.pbs.org/wnet/nature/blog/camel-fact-sheet/#:~:text=One%20of%20the%20camel's%20most,used%20as%20an%20energy%20source.
bactrianize = pascalize;
dromedize = camelize;