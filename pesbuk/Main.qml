import QtQuick 2.9
import QtQuick.Controls 2.2
import Ubuntu.Components 1.3
import Ubuntu.PushNotifications 0.1
import "components"

ApplicationWindow {
    id: appWindow
    
    readonly property QtObject drawer: drawerLoader.item
    property alias webview: webViewPage.webView
    property alias leftSwipeArea: leftSwipeAreaLoader.item
    property alias rightSwipeArea: rightSwipeAreaLoader.item
    
    property string displayMode: "Phone" //"Desktop" //"Phone" //"Tablet"
    
    visible: true
    title: "Pesbuk"
    
    width: switch (displayMode) {
               case "Phone":
                   units.gu(50)
                   break
               case "Tablet":
                   units.gu(100)
                   break
               case "Desktop":
                   units.gu(120)
                   break
               default:
                   units.gu(120)
                   break
               }
        height: switch (displayMode) {
                case "Phone":
                    units.gu(89)
                    break
                case "Tablet":
                    units.gu(56)
                    break
                case "Desktop":
                    units.gu(68)
                    break
                default:
                    units.gu(68)
                    break
                }
    
    header: ApplicationHeader{
            id: applicationHeader
            
            flickable: stackView.currentItem.flickable
            leftActions: [menuAction]
            rightActions: stackView.currentItem ? stackView.currentItem.headerRightActions : 0
            expandable: appSettings.headerExpand
            
            Connections {
                enabled: webViewPage.webView
                target: webViewPage.webView
                onScrollPositionChanged: {
                    if (target.loadProgress == 100) {
                        timer.restart()
                    }
                }
            }
            
            Timer {
                id: timer

                running: false
                interval: 400
                onTriggered: {
                    if (!applicationHeader.expanded) {
                        if (webViewPage.scrollDirection == "Downwards" && webViewPage.webView.scrollPosition.y > 2 && appSettings.headerAutoHide) {
                            applicationHeader.state = "Hidden"
                        } else {
                            applicationHeader.state = "Default"
                        }
                    }
                }
            }
        }
    
    MainView{
        id: mainView
        
        applicationName: "pesbuk.kugiigi"
        anchors.fill: parent
        objectName: "mainView"  
        
        readonly property string version: "1.8"
        
        readonly property string siteMode: switch (true) {
                                    case width >= units.gu(120):
                                        "Desktop"
                                        break
                                    default:
                                        "Phone"
                                        break
                                }
        readonly property bool desktopMode: appSettings.baseSite === 2 || (appSettings.baseSite === 3 && mainView.siteMode === "Desktop")
        
        property bool blockOpenExternalUrls: false
        property bool runningLocalApplication: false
        property bool openExternalUrlInOverlay: false
        property bool popupBlockerEnabled: true
        property bool fullscreen: false
        
        theme.name: appSettings.style === "Suru" ? "" : "Ubuntu.Components.Themes.Ambiance"
        
        BaseHeaderAction{
            id: menuAction
            
            enabled: drawerLoader.visible
            text: stackView.depth > 1 ? i18n.tr("Back") : i18n.tr("Menu")
            iconName: stackView.depth > 1 ? "back" : "navigation-menu"
            notifText: stackView.depth === 1 ? webViewPage.notificationExists : ""
            shortcut: stackView.depth > 1 ? StandardKey.Cancel : "Menu"
            onTrigger:{
                if (stackView.depth > 1) {
                        stackView.pop()
                        drawer.resetListIndex()
                    } else {
                        if(isBottom){
                            drawer.openBottom()
                        }else{
                            drawer.openTop()
                        }
                    }
                }
        }
        
        // TODO: Not working
        Component.onCompleted: {
            if (args.values.url) {
                console.log("Incoming notification on Closed App: " + args.values.url)
                processURI(args.values.url)
            } else if (Qt.application.arguments && Qt.application.arguments.length > 0) {
        
                for (var i = 0; i < Qt.application.arguments.length; i++) {
                    if (Qt.application.arguments[i].match(/^pesbuk/) || Qt.application.arguments[i].match(/^https/)) {
                        console.log("Incoming notification: " + Qt.application.arguments[i])
                        processURI(Qt.application.arguments[i])
                    }
                }
            }
            
        }
        
        function processURI(uri){
            if(uri.match(/^pesbuk/)){
                var actionName = uri.replace("pesbuk://", "")
                
                switch(actionName){
                    case "messages":
                        webViewPage.webView.url = webViewPage.baseURL + "/messages"
                    break
                    case "notifications":
                        webViewPage.webView.url = webViewPage.baseURL + "/notifications"
                    break
                    case "requests":
                        webViewPage.webView.url = webViewPage.baseURL + "/friends/center/requests"
                    break
                    case "feeds":
                        webViewPage.webView.url = webViewPage.home
                    break
                }
            }
            
            if(uri.match(/^https/)){
                webViewPage.webView.url = uri
            }
        }
        
        Arguments {
            id: args
        
            Argument {
                name: 'url'
                help: i18n.tr('Facebook URL/Action')
                required: false
                valueNames: ['URL']
            }
        }
        
        Connections {
            target: UriHandler
        
            onOpened: {
                console.log('Open from UriHandler')
        
                if (uris.length > 0) {
                    console.log('Incoming notification from UriHandler ' + uris[0]);
                    mainView.processURI(uris[0])
                }
            }
        }

        WebViewPage{
            id: webViewPage
        }
       
        StackView {
            id: stackView
            
            initialItem: webViewPage
            
            anchors{
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: keyboardRec.top
            }
            
            onDepthChanged: if (depth > 1) applicationHeader.state = "Default"
        }
       
        SettingsComponent{
            id: appSettings
        }
       
        KeyboardRectangle{
            id: keyboardRec
        }
        
        PushClient {
            id: pushClient
            
            appId: "pesbuk.kugiigi_pesbuk"
            onTokenChanged: appSettings.pushToken = token
            
            onCountChanged: console.log("count: " + count)
            
            function sendPush(tag, title, body, iconName, url, sound){
                if(!appWindow.active){
                    var req = new XMLHttpRequest();
                    req.open("post", "https://push.ubports.com/notify", true);
                    req.setRequestHeader("Content-type", "application/json");
                    req.onreadystatechange = function() {
                            if ( req.readyState === XMLHttpRequest.DONE ) {
                                            console.log("push notification: ", req.responseText);
                            }
                    }
                    var approxExpire = new Date ();
                    approxExpire.setUTCMinutes(approxExpire.getUTCMinutes()+10);
                    var jsonData = JSON.stringify({
                            "appid" : appId,
                            "expire_on": approxExpire.toISOString(),
                            "token": appSettings.pushToken,
                            "replace_tag": tag,
                            "data": {
                                    "notification": {
                                            "tag": tag,
                                            "card": {
                                                    "actions": [url],
                                                    "icon": iconName,
                                                    "summary": title,
                                                    "body": body,
                                                    "popup": true,
                                                    "persist": true
                                            },
                                            "vibrate": true,
                                            "sound": sound,
                                            "emblem-counter": {
                                                "count": webViewPage.notifyCount,
                                                "visible": webViewPage.notifyCount ? true : false
                                            }
                                    }
                            }
                    })
                    req.send(jsonData);
                }
            }
        }
        
        Loader {
            id: drawerLoader
            
            readonly property var moreActions: [
                        { title: i18n.tr("View Profile"), type: "JS",url: "var menuButton = document.querySelector('a[name=More].touchable'); if(menuButton){menuButton.click()}; setTimeout(function(){var button = document.querySelector('div.mSideMenu ul li div.touchable a'); if(button){button.click()}}, 1000)", iconName: "account" }
                        ,{ title: i18n.tr("Marketplace"), type: "URL",url: webViewPage.baseURL + "/marketplace", iconName: "stock_store" }
                        ,{ title: i18n.tr("Pages"), type: "URL",url: webViewPage.baseURL + "/nt/?id=%2Fpages%2Fnt_launchpoint%2Fhome_pages%2F", iconName: "stock_document" }
                        ,{ title: i18n.tr("Saved"), type: "URL",url: webViewPage.baseURL + "/saved", iconName: "bookmark" }
                        ,{ title: i18n.tr("Groups"), type: "URL",url: webViewPage.baseURL + "/groups", iconName: "contact-group" }
                        ,{ title: i18n.tr("Events"), type: "URL",url: webViewPage.baseURL + "/events", iconName: "event" }
                        ,{ title: i18n.tr("On This Day"), type: "URL",url: webViewPage.baseURL + "/onthisday", iconName: "calendar-today" }
                        ,{ title: i18n.tr("Buy and Sell Groups"), type: "URL",url: webViewPage.baseURL + "/salegroups", iconName: "tag" }
                        ,{ title: i18n.tr("Jobs"), type: "URL",url: webViewPage.baseURL + "/jobs", iconName: "preferences-desktop-accessibility-symbolic" }
                    ]
            
            active: true
            asynchronous: true
            sourceComponent: MenuDrawer{
                    id: drawer
                     
                     model:  [
                        { title: i18n.tr("Notifications"), type: "URL" ,url: webViewPage.baseURL + "/notifications", iconName: "notification", notifyText: webViewPage.notificationsCount }
                        ,{ title: i18n.tr("Messages"), type: "URL",url: (appSettings.messengerDesktop ? "https://www.facebook.com" : webViewPage.baseURL) + "/messages", iconName: "message", notifyText: webViewPage.messagesCount }
                        ,{ title: i18n.tr("Feeds"), type: "JS",url: "var button = document.querySelector('a[name=" + "\"News Feed\"" + "].touchable'); if(button){button.click()}", iconName: "rssreader-app-symbolic", notifyText: webViewPage.feedsCount }
                        ,{ title: i18n.tr("Friends"), type: "URL",url: webViewPage.baseURL + "/friends" + (!mainView.desktopMode ? "/center/requests/" : ""), iconName: "contact", notifyText: webViewPage.requestsCount }
                        ,{ title: i18n.tr("Search"), type: "JS",url: "var button = document.querySelector('a[name=Search].touchable'); if(button){button.click()}", iconName: "find" }
                        ,{ title: i18n.tr("Menu"), type: "JS",url: "var button = document.querySelector('a[name=More].touchable'); if(button){button.click()};", iconName: "navigation-menu" }
                        ,{ title: i18n.tr("More"), type: "Menu",url: moreActions, iconName: "other-actions" }
                        ,{ title: i18n.tr("Settings"), type: "PAGE",url: Qt.resolvedUrl("SettingsPage.qml"), iconName: "settings" }
                        ,{ title: i18n.tr("About"), type: "PAGE",url: Qt.resolvedUrl("AboutPage.qml"), iconName: "info" }
                    ]
                }

            visible: status == Loader.Ready
        }
        
        Loader {
            id: rightSwipeAreaLoader
            
            z: 20
            active: true
            asynchronous: true
            visible: status == Loader.Ready
            sourceComponent: BottomSwipeArea{
                onTriggered: applicationHeader.triggerRight(true)
            }
            
            anchors{
                right: parent.right
                left: parent.horizontalCenter
                bottom: parent.bottom
            }
        }  
        
        Loader {
            id: leftSwipeAreaLoader
            
            z: 20
            active: true
            asynchronous: true
            visible: status == Loader.Ready
            sourceComponent: BottomSwipeArea{
                onTriggered: applicationHeader.triggerLeft(true)
            }
            
            anchors{
                left: parent.left
                right: parent.horizontalCenter
                bottom: parent.bottom
            }
        } 
        
        Loader {
            id: bottomEdgeHintLoader
            
            z: 10
            active: appSettings.firstRun
            asynchronous: true
            visible: status == Loader.Ready
            sourceComponent: BottomEdgeHint{}
            
            anchors{
                fill: parent
            }
        } 

        // F5 or Ctrl+R: Reload current Tab
        Shortcut {
            sequence: "Ctrl+r"
            enabled: webViewPage.webView
            onActivated: webViewPage.webView.reload()
        }
        Shortcut {
            sequence: "F5"
            enabled: webViewPage.webView
            onActivated: webViewPage.webView.reload()
        }

        // Alt+← or Backspace: Goes to the previous page
        Shortcut {
            sequence: StandardKey.Back
            enabled: webViewPage.webView && webViewPage.webView.canGoBack
            onActivated: webViewPage.webView.goBack()
        }

        // Alt+→ or Shift+Backspace: Goes to the next page
        Shortcut {
            sequence: StandardKey.Forward
            enabled: webViewPage.webView && webViewPage.webView.canGoForward
            onActivated: webViewPage.webView.goForward()
        }

        Shortcut {
            sequence: StandardKey.Cancel
            enabled: stackView.depth > 1
            onActivated: menuAction.trigger(false)
        }
        Shortcut {
            sequence: "Menu"
            enabled: stackView.depth <= 1
            onActivated: menuAction.trigger(false)
        }
    }
   
 }   

