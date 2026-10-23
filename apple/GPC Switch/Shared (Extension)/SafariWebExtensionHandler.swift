import SafariServices
import os.log

// The extension declares no `nativeMessaging` permission, so Safari never
// sends it messages and this handler is inert. It exists because every Safari
// web extension target needs an NSExtensionRequestHandling principal class.
class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey]
        os_log(.default, "GPC Switch: unexpected native message: %@", String(describing: message))
        context.completeRequest(returningItems: nil, completionHandler: nil)
    }

}
