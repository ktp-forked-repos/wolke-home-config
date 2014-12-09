// ==UserScript==
// @name        github-username
// @namespace   teleshoes
// @require     file:///home/wolke/greasemonkey/github-username/secret.js
// @include     https://github.com/*
// @version     1
// @grant       none
// ==/UserScript==

baseUrl = "https://github.com"

function main(){
  url = document.URL;

  landingPage = isLandingPage();
  targetUserName = getTargetUserName(url);
  userName = getUserName();

  if(userName != null && targetUserName != null && userName != targetUserName){
    logout();
    setTimeout(navToLogin, 100);
  }else if(targetUserName != null && /github.com\/login/.exec(url)){
    login(targetUserName);
  }else if(landingPage){
    if(targetUserName == null){
      targetUserName = getTargetUserName(document.referrer);
    }
    if(targetUserName != null){
      navToLogin(targetUserName);
    }
  }else if(is404()){
    if(/[?\/]lillegroup/.exec(url)){
      targetUserName = "ewolk";
      newUrl = baseUrl + "/" + targetUserName;
      window.open(newUrl, '_blank', true);
      setTimeout(function(){ location.reload(true) }, 5000);
    }
  }
}

function isLandingPage(){
  btns = document.getElementsByClassName('signin');
  if(btns.length == 1 && /\/login$/.exec(btns[0].href)){
    return true;
  }
  return false;
}

function is404(){
  return /Page not found/.exec(document.title) ? true : false;
}

function getTargetUserName(url){
  if(/[?\/]teleshoes/.exec(url)){
    return "teleshoes";
  }else if(/[?\/]ewolk/.exec(url)){
    return "ewolk";
  }else{
    return null;
  }
}

function navToLogin(userName){
  newUrl = baseUrl + "/login?" + targetUserName;
  window.open(newUrl, '_self', false);
}

function login(userName){
  un = document.getElementById('login_field');
  pw = document.getElementById('password');

  btn = null;
  login = document.getElementById('login');
  if(login != null){
    btns = login.getElementsByClassName('button');
    if(btns.length == 1){
      btn = btns[0];
    }
  }

  if(un != null && pw != null && btn != null){
    un.value = userName;
    pw.value = secret[userName];
    btn.click();
  }
}

function logout(){
  document.getElementsByClassName('logout-form')[0].submit();
}

function getUserName(){
  ul = document.getElementById('user-links');
  if(ul != null){
    as = ul.getElementsByTagName("a");
    if(as.length > 0){
      a = as[0];
      href = a.href;
      arr = /\/([a-zA-Z0-9_]+)$/.exec(href);
      if(arr != null && arr.length == 2){
        return arr[1];
      }
    }
  }
  return null;
}

main();
