//
//  CidaasView.swift
//  Cidaas
//
//  Created by ganesh on 16/01/19.
//

import Foundation
import UIKit
import WebKit

public class CidaasView: UIView, WKNavigationDelegate {
    
    public var loaderDelegate: CidaasLoaderDelegate!
    
    public var enableNativeFacebook : Bool = false
    public var enableNativeGoogle : Bool = false
    public static var facebookDelegate: CidaasFacebookDelegate!
    public static var googleDelegate: CidaasGoogleDelegate!
    public var viewType: String = "login"
    public var requestId: String = ""
    
    var browserCallback: ((Result<LoginResponseEntity>) -> ())!
    // instance of webview
    var wkWebView : WKWebView!
    var view: UIView!
    var delegate: WKNavigationDelegate!
    
    @IBOutlet var backButton: UIButton!
    
    // webview constraints
    var webViewTopConstraint : NSLayoutConstraint!
    var webViewBottomConstraint : NSLayoutConstraint!
    var webViewTrailConstraint : NSLayoutConstraint!
    var webViewLeadConstraint : NSLayoutConstraint!
    
    var enableBackButton: Bool = false
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        self.wkWebView = WKWebView(frame : CGRect.zero)
        super.init(coder: aDecoder)
        setup()
    }
    
    // back button flag
    public var ENABLE_BACK_BUTTON : Bool {
        get {
            enableBackButton = DBHelper.shared.getEnableLog()
            return enableBackButton
        }
        set (enableBackButton) {
            self.enableBackButton = enableBackButton
            // save local
            DBHelper.shared.setEnableBackButton(enableBackButton: enableBackButton)
        }
    }
    
    func setup() {
        view = loadViewFromNib()
        view.frame = bounds
        view.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth, UIView.AutoresizingMask.flexibleHeight]
        addSubview(view)
        
        if wkWebView != nil {
            view.addSubview(wkWebView)
            wkWebView.translatesAutoresizingMaskIntoConstraints = false
            showWebview()
            webViewTopConstraint = NSLayoutConstraint(item: wkWebView!, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: 0)
            webViewBottomConstraint = NSLayoutConstraint(item: wkWebView!, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: 0)
            webViewTrailConstraint = NSLayoutConstraint(item: wkWebView!, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1, constant: 0)
            webViewLeadConstraint = NSLayoutConstraint(item: wkWebView!, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 0)
            view.addConstraints([webViewTopConstraint, webViewBottomConstraint, webViewTrailConstraint, webViewLeadConstraint])
        }
    }
    
    private func loadViewFromNib() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: "CidaasView", bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil)[0] as! UIView
        return view
        
    }
    
    func loginWithEmbeddedBrowser(delegate: WKNavigationDelegate, extraParams: Dictionary<String, String>, properties: Dictionary<String, String>, callback: @escaping(Result<LoginResponseEntity>) -> Void) {
        // null check
        if properties["DomainURL"] == "" || properties["DomainURL"] == nil || properties["ClientId"] == "" || properties["ClientId"] == nil || properties["RedirectURL"] == "" || properties["RedirectURL"] == nil {
            let error = WebAuthError.shared.propertyMissingException()
            // log error
            let loggerMessage = "Read properties failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
        
        // construct url
        let loginURL = LoginController.shared.constructURL(extraParams: extraParams, properties: properties)
        login(delegate: delegate, loginURL: URLRequest(url: loginURL), callback: callback)
        
    }
    
// -------------------------------------------------------------------------------------------------- //
    
    // login with embedded browser
    public func loginWithEmbeddedBrowser(delegate: WKNavigationDelegate, extraParams: Dictionary<String, String> = Dictionary<String, String>(), callback: @escaping (Result<LoginResponseEntity>) -> Void) {
        var savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            self.browserCallback = callback
            self.delegate = delegate
            // assign view type
            if extraParams["view_type"] != nil {
                savedProp!["ViewType"] = extraParams["view_type"]
                self.viewType = extraParams["view_type"]!
            }
            if extraParams["requestId"] != nil {
                self.requestId = extraParams["requestId"]!
            }
            loginWithEmbeddedBrowser(delegate: delegate, extraParams: extraParams, properties: savedProp!, callback: callback)
        }
        else {
            // log error
            let loggerMessage = "Read properties file failure : " + "Error Code -  10001, Error Message -  File not found, Status Code - 404"
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            let error = WebAuthError.shared.fileNotFoundException()
            
            // return failure callback
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
    }
    
    func showLoader() {
        if loaderDelegate != nil {
            loaderDelegate.showLoader()
        }
    }
    
    func hideLoader() {
        if loaderDelegate != nil {
            loaderDelegate.hideLoader()
        }
    }
    
    func hideWebview() {
        wkWebView.isHidden = true
    }
    
    func showWebview() {
        wkWebView.isHidden = false
    }
    
    func hideBackButton() {
        if enableBackButton == true {
            backButton.isHidden = true
            webViewBottomConstraint.constant = 0
        }
    }
    
    func showBackButton() {
        if enableBackButton == true {
            backButton.isHidden = false
            webViewBottomConstraint.constant = -60
        }
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // show loader
        showLoader()
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // hide loader
        hideLoader()
        
        let urlString = webView.url?.absoluteString
        let savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            let domainURL = savedProp!["DomainURL"] ?? ""
            if (urlString?.starts(with: domainURL) == true) {
                // hide back button
                hideBackButton()
            }
            else {
                // show back button
                showBackButton()
            }
            
            if (urlString?.contains("code=") == true) {
                let url = URL(string: urlString!)
                let code = url!.valueOf("code") ?? ""
                
                // show loader
                showLoader()
                
                // hide webview
                hideWebview()
                
                AccessTokenController.shared.getAccessToken(code: code) {
                    switch $0 {
                        case .success(let successResponse):
                            // hide loader
                            self.hideLoader()
                            
                            DispatchQueue.main.async {
                                self.browserCallback(Result.success(result: successResponse))
                            }
                            break
                        case .failure(let errorResponse):
                            // hide loader
                            self.hideLoader()
                            
                            DispatchQueue.main.async {
                                self.browserCallback(Result.failure(error: errorResponse))
                            }
                            break
                    }
                }
            }
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        let url = navigationAction.request.url
        
        // check facebook native enabled
        if enableNativeFacebook == true {
            if (CidaasView.facebookDelegate == nil) {
                browserCallback(Result.failure(error: WebAuthError.shared.delegateMissingException()))
                // callback handler
                decisionHandler(.cancel)
                return
            }
            
            let urlMatchString = "social/" + self.viewType + "/facebook"
            
            // check facebook url exists
            if (url?.relativeString.contains(urlMatchString))! {
                
                // hide webview and loader
                hideWebview()
                hideLoader()
                webView.stopLoading()
                
                // call the facebook sdk flow method
                facebookSDKFlow()
                
                // callback handler
                decisionHandler(.cancel)
                return
            }
        }
        
        // check google native enabled
        if enableNativeGoogle == true {
            if (CidaasView.googleDelegate == nil) {
                // callback handler
                decisionHandler(.cancel)
                browserCallback(Result.failure(error: WebAuthError.shared.delegateMissingException()))
                return
            }
            
            let urlMatchString = "social/" + self.viewType + "/google"
            
            // check facebook url exists
            if (url?.relativeString.contains(urlMatchString))! {
                
                // hide webview and loader
                hideWebview()
                hideLoader()
                webView.stopLoading()
                
                // call the google sdk flow method
                googleSDKFlow()
                
                // callback handler
                decisionHandler(.cancel)
                return
            }
        }
        
        // allow handler by default
        decisionHandler(.allow)
    }
    
    func facebookSDKFlow() {
        hideWebview()
        hideBackButton()
        
        CidaasView.facebookDelegate.login(viewType: self.viewType, requestId: self.requestId, callback: self.browserCallback)
    }
    
    func googleSDKFlow() {
        hideWebview()
        hideBackButton()
        
        CidaasView.googleDelegate.login(viewType: self.viewType, callback: self.browserCallback)
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // hide loader
        hideLoader()
        
        let nserror = error as NSError
        if nserror.code != -999 {
            // show error message in web
        }
    }
    
    func login(delegate: WKNavigationDelegate, loginURL: URLRequest, callback: @escaping (Result<LoginResponseEntity>) -> Void) {
        
        clearCookies()
        
        // assign delegate
        wkWebView.navigationDelegate = delegate
        
        let device = getDeviceDetails()
        
        // user agent
        wkWebView.customUserAgent = "Mozilla/5.0 (\(device.0); CPU \(device.1) OS \(device.2) like Mac OS X) AppleWebKit/537.36 (KHTML, like Gecko) Version/11.0 Mobile/15E148 Safari/604.1"
        
        wkWebView.load(loginURL)
    }
    
    func getDeviceDetails() -> (String, String, String) {
        let deviceHelper = DeviceHelper()
        var deviceModel = String(describing: deviceHelper.hardware())
        let deviceFullModel = deviceModel
        
        if deviceModel.starts(with: "iphone") {
            deviceModel = "iPhone"
        }
        if deviceModel.starts(with: "ipad") {
            deviceModel = "iPad"
        }
        var deviceVersion = UIDevice.current.systemVersion
        deviceVersion = deviceVersion.replacingOccurrences(of: ".", with: "_")
        
        return (deviceModel, deviceFullModel, deviceVersion)
    }
    
    @IBAction func backButtonAction(_ sender: Any) {
        if wkWebView.canGoBack {
            wkWebView.goBack()
        }
    }
    
    public func setBackButtonAttributes(title: String, textColor: UIColor, backgroundColor: UIColor) {
        backButton.setTitle(title, for: .normal)
        backButton.setTitleColor(textColor, for: .normal)
        backButton.backgroundColor = backgroundColor
    }
    
    public func logout(sub: String, post_logout_url: String = "") {
        AccessTokenController.shared.getAccessToken(sub: sub) {
            switch $0 {
                case .success(let successResponse):
                    self.logout(accessToken: successResponse.data.access_token, post_logout_url: post_logout_url)
                    break
                case .failure( _):
                    break
            }
        }
    }
    
    public func logout(accessToken: String, post_logout_url: String = "") {
        let savedProp = DBHelper.shared.getPropertyFile()
        if savedProp != nil {
            let baseURL = savedProp!["DomainURL"] ?? ""
            let logoutURLString = baseURL + URLHelper.shared.getLogoutURL(accessToken: accessToken)
            let logoutURL = URLRequest(url: URL(string: logoutURLString)!)
            wkWebView.isHidden = false
            wkWebView.load(logoutURL)
        }
    }
    
    func clearCookies() {
        // clear all cookies
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        CidaasSessionCookies.clear()
        print("[WebCacheCleaner] All cookies deleted")
        
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { (records) in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                print("[WebCacheCleaner] Record \(record) deleted")
            }
        }
    }
}
