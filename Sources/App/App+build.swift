import Foundation
import Hummingbird
import Logging
import Mustache

/// Router errors
enum RouterError: Error {
    case templateDirectoryNotFound
}

/// Load Mustache templates from a directory
func loadTemplates(from directory: String) throws -> [String: MustacheTemplate] {
    let fileManager = FileManager.default
    var templates: [String: MustacheTemplate] = [:]

    guard let enumerator = fileManager.enumerator(atPath: directory) else {
        return templates
    }

    for case let file as String in enumerator {
        guard file.hasSuffix(".mustache") else { continue }

        let templatePath = (directory as NSString).appendingPathComponent(file)
        let templateName = (file as NSString).deletingPathExtension

        templates[templateName] = try MustacheTemplate(string: String(contentsOfFile: templatePath))
    }

    return templates
}

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable. 
/// Any variables added here also have to be added to `App` in App.swift and 
/// `TestArguments` in AppTest.swift
package protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
}

// Request context used by application
typealias AppRequestContext = BasicRequestContext

///  Build application
/// - Parameter arguments: application arguments
func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    let environment = Environment()
    let logger = {
        var logger = Logger(label: "site")
        logger.logLevel = 
            arguments.logLevel ??
            environment.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ??
            .info
        return logger
    }()
    let router = try buildRouter()
    let app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "site"
        ),
        logger: logger
    )
    return app
}

/// Build router
func buildRouter() throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)

    // Get the Templates directory from the bundle
    guard let templatesURL = Bundle.module.resourceURL?.appendingPathComponent("Templates") else {
        throw RouterError.templateDirectoryNotFound
    }

    // Load templates from directory and initialize Mustache library
    let templates = try loadTemplates(from: templatesURL.path)
    let mustacheLibrary = MustacheLibrary(templates: templates)

    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
    }

    // Serve static CSS file
    router.get("/system.css") { request, context in
        guard let publicURL = Bundle.module.resourceURL?.appendingPathComponent("Public/system.css"),
              let cssContent = try? String(contentsOf: publicURL) else {
            return Response(status: .notFound)
        }

        return Response(
            status: .ok,
            headers: [.contentType: "text/css; charset=utf-8"],
            body: .init(byteBuffer: ByteBuffer(string: cssContent))
        )
    }

    // Home page
    router.get("/") { request, context in
        let homeData: [String: Any] = [
            "greeting": "/dev/disk1s1",
            "message": "Altheman's OS System 25.0",
            "features": [
                ["name": "Swift Powered", "description": "Built with Swift and Hummingbird framework"],
                ["name": "Mustache Templates", "description": "Dynamic HTML rendering with Mustache"]
            ]
        ]

        let homeContent = mustacheLibrary.render(homeData, withTemplate: "home") ?? ""

        let layoutData: [String: Any] = [
            "title": "Home",
            "content": homeContent
        ]

        let html = mustacheLibrary.render(layoutData, withTemplate: "layout") ?? ""

        return Response(
            status: .ok,
            headers: [.contentType: "text/html; charset=utf-8"],
            body: .init(byteBuffer: ByteBuffer(string: html))
        )
    }

    // About page
    router.get("/about") { request, context in
        let aboutData: [String: Any] = [
            "name": "Altheman",
            "bio": "A passionate developer working with Swift, Hummingbird, and modern web technologies. Building fast and reliable web applications with a focus on clean code and great user experience.",
            "skills": [
                "Swift",
                "Hummingbird Framework",
                "Mustache Templating",
                "Web Development",
                "API Design",
                "Cloud Deployment"
            ]
        ]

        let aboutContent = mustacheLibrary.render(aboutData, withTemplate: "about") ?? ""

        let layoutData: [String: Any] = [
            "title": "About",
            "content": aboutContent
        ]

        let html = mustacheLibrary.render(layoutData, withTemplate: "layout") ?? ""

        return Response(
            status: .ok,
            headers: [.contentType: "text/html; charset=utf-8"],
            body: .init(byteBuffer: ByteBuffer(string: html))
        )
    }

    // Contact page
    router.get("/contact") { request, context in
        let contactData: [String: Any] = [
            "contacts": [
                ["type": "Email", "value": "contact@altheman.dev"],
                ["type": "GitHub", "value": "github.com/altheman"],
                ["type": "Twitter", "value": "@altheman"]
            ],
            "footer_message": "I typically respond within 24 hours. Looking forward to hearing from you!"
        ]

        let contactContent = mustacheLibrary.render(contactData, withTemplate: "contact") ?? ""

        let layoutData: [String: Any] = [
            "title": "Contact",
            "content": contactContent
        ]

        let html = mustacheLibrary.render(layoutData, withTemplate: "layout") ?? ""

        return Response(
            status: .ok,
            headers: [.contentType: "text/html; charset=utf-8"],
            body: .init(byteBuffer: ByteBuffer(string: html))
        )
    }

    return router
}
