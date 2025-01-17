//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import WebKit
public let TRONMainNet: String = "https://api.trongrid.io"
public let TRONNileNet: String = "https://nile.trongrid.io"
public let TRONApiKey: String = "188434ac-470f-494e-8241-830ed5cb00fc"
extension TronWeb3: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if self.showLog { print("didFinish") }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if self.showLog { print("error = \(error)") }
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if self.showLog { print("didStartProvisionalNavigation ") }
    }
}

public class TronWeb3: NSObject {
    var webView: WKWebView!
    var bridge: WKWebViewJavascriptBridge!
    public var isGenerateTronWebInstanceSuccess: Bool = false
    var onCompleted: ((Bool) -> Void)?
    var showLog: Bool = true
    override public init() {
        super.init()
        let webConfiguration = WKWebViewConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: webConfiguration)
        self.webView.navigationDelegate = self
        self.webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        self.bridge = WKWebViewJavascriptBridge(webView: self.webView,isHookConsole: false)
    }

    deinit {
        print("\(type(of: self)) release")
    }

    public func setup(showLog: Bool = true, privateKey: String? = "", apiKey: String? = TRONApiKey, node: String = TRONNileNet, onCompleted: ((Bool) -> Void)? = nil) {
        self.onCompleted = onCompleted
        self.showLog = showLog
        #if !DEBUG
        self.showLog = false
        #endif
        self.bridge.register(handlerName: "FinishLoad") { [weak self] _, _ in
            guard let self = self else { return }
            self.generateTronWebInstance(privateKey: privateKey, apiKey: apiKey, node: node)
        }
        let htmlSource = self.loadBundleResource(bundleName: "TronWeb", sourceName: "/TronIndex.html")
        let url = URL(fileURLWithPath: htmlSource)
        DispatchQueue.main.async { [self] in
            self.webView.loadFileURL(url, allowingReadAccessTo: url)
        }
    }

    func loadBundleResource(bundleName: String, sourceName: String) -> String {
        var bundleResourcePath = Bundle.main.path(forResource: "Frameworks/\(bundleName).framework/\(bundleName)", ofType: "bundle")
        if bundleResourcePath == nil {
            bundleResourcePath = Bundle.main.path(forResource: bundleName, ofType: "bundle") ?? ""
        }
        return bundleResourcePath! + sourceName
    }

    func generateTronWebInstance(privateKey: String?, apiKey: String? = TRONApiKey, node: String = TRONNileNet) {
        let params = ["privateKey": privateKey, "node": node, "apiKey": apiKey]
        self.bridge.call(handlerName: "generateTronWebInstance", data: params) { [weak self] result in
            guard let self = self, let result = result as? [String: String], let result = result["result"] else { return }
            if result == "1" {
                self.isGenerateTronWebInstanceSuccess = true
                if self.showLog { print("TronWeb初始化成功") }
                self.onCompleted?(true)
            } else {
                self.isGenerateTronWebInstanceSuccess = false
                if self.showLog { print("TronWeb初始化失败") }
                self.onCompleted?(false)
            }
        }
    }

    public func tronWebResetPrivateKey(privateKey: String, onCompleted: ((Bool) -> Void)? = nil) {
        let params: [String: String] = ["privateKey": privateKey]
        self.bridge.call(handlerName: "resetPrivateKey", data: params) { response in
            if self.showLog { print("response = \(String(describing: response))") }
            guard let response = response as? [String: Bool] else {
                onCompleted?(false)
                return
            }
            if let result = response["result"] {
                onCompleted?(result)
            } else {
                onCompleted?(false)
            }
        }
    }

    // MARK: 獲取trx餘額

    public func getRTXBalance(address: String, onCompleted: ((Bool, String) -> Void)? = nil) {
        let params: [String: String] = ["address": address]
        self.bridge.call(handlerName: "getTRXBalance", data: params) { response in
            if self.showLog { print("response = \(String(describing: response))") }
            guard let temp = response as? [String: Any], let state = temp["state"] as? Bool else {
                onCompleted?(false, "error")
                return
            }
            if let balance = temp["result"] as? String {
                onCompleted?(state, balance)
            }
        }
    }

    // MARK: 獲取trc20代幣餘額

    public func getTRC20TokenBalance(address: String,
                                     trc20ContractAddress: String,
                                     decimalPoints: Double,
                                     onCompleted: ((Bool, String) -> Void)? = nil)
    {
        let params: [String: Any] = ["address": address,
                                     "trc20ContractAddress": trc20ContractAddress,
                                     "decimalPoints": decimalPoints]
        self.bridge.call(handlerName: "getTRC20TokenBalance", data: params) { response in
            if self.showLog { print("response = \(String(describing: response))") }
            guard let temp = response as? [String: Any], let state = temp["state"] as? Bool else {
                onCompleted?(false, "error")
                return
            }
            if let balance = temp["result"] as? String {
                onCompleted?(state, balance)
            }
        }
    }

    // MARK: trx轉帳 支持備註版本

    public func trxTransferWithRemark(remark: String,
                                      toAddress: String,
                                      amount: String,
                                      onCompleted: ((Bool, String) -> Void)? = nil)
    {
        let params: [String: String] = ["toAddress": toAddress,
                                        "amount": amount,
                                        "remark": remark]
        self.bridge.call(handlerName: "trxTransferWithRemark", data: params) { response in
            if self.showLog { print("response = \(String(describing: response))") }
            guard let temp = response as? [String: Any], let state = temp["result"] as? Bool, let txid = temp["txid"] as? String else {
                onCompleted?(false, "error")
                return
            }
            onCompleted?(state, txid)
        }
    }

    // MARK: trx轉帳 不支持備註版本

    public func trxTransfer(toAddress: String,
                            amount: String,
                            onCompleted: ((Bool, String) -> Void)? = nil)
    {
        let params: [String: String] = ["toAddress": toAddress,
                                        "amount": amount]
        self.bridge.call(handlerName: "trxTransfer", data: params) { response in
            if self.showLog { print("response = \(String(describing: response))") }
            guard let temp = response as? [String: Any], let state = temp["result"] as? Bool, let txid = temp["txid"] as? String else {
                onCompleted?(false, "error")
                return
            }
            onCompleted?(state, txid)
        }
    }

    // MARK: trc20代幣轉帳

    public func trc20TokenTransfer(toAddress: String,
                                   trc20ContractAddress: String,
                                   amount: String,
                                   remark: String,
                                   feeLimit: String = "100000000",
                                   onCompleted: ((Bool, String) -> Void)? = nil)
    {
        let params: [String: String] = ["trc20ContractAddress": trc20ContractAddress,
                                        "toAddress": toAddress,
                                        "amount": amount,
                                        "feeLimit": feeLimit,
                                        "remark": remark]
        self.bridge.call(handlerName: "tokenTransfer", data: params) { response in
            if self.showLog { print("response = \(String(describing: response))") }
            guard let temp = response as? [String: Any], let state = temp["result"] as? Bool, let txid = temp["txid"] as? String else {
                onCompleted?(false, "error")
                return
            }
            onCompleted?(state, txid)
        }
    }

    // MARK: 校驗是否是TRX的地址

    public func isTRXAddress(address: String, onCompleted: ((Bool) -> Void)? = nil) {
        let params: [String: String] = ["address": address]
        self.bridge.call(handlerName: "isTRXAddress", data: params) { response in
            guard let isTRXAddress = response as? Bool else {
                onCompleted?(false)
                return
            }
            onCompleted?(isTRXAddress)
        }
    }

    // MARK: 根據地址獲取帳戶資訊

    public func getAccount(address: String, onCompleted: (([String: Any]) -> Void)? = nil) {
        let params: [String: String] = ["address": address]
        self.bridge.call(handlerName: "getAccount", data: params) { response in
            if self.showLog { print("response = \(String(describing: response))") }
            guard let data = response as? [String: Any] else {
                onCompleted?([:])
                return
            }
            onCompleted?(data)
        }
    }
}
