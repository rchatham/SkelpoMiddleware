import Authentication
import JWTProvider
import Fluent
import Crypto
import Vapor

public protocol BasicJWTAuthenticatable: JWTAuthenticatable where AuthBody == BasicAuthorization, Database: QuerySupporting {
    static var usernameKey: KeyPath<Self, String> { get }
    
    var password: String { get }
}

extension BasicJWTAuthenticatable {
    public static func authBody(from request: Request)throws -> AuthBody? {
        return request.http.headers.basicAuthorization
    }
    
    public static func authenticate(from payload: Payload, on request: Request)throws -> Future<Self> {
        return try Self.find(payload.id, on: request).unwrap(
            or: Abort(.notFound, reason: "No user found with the ID from the access token")
        ).map(to: Self.self, { (model) in
            try request.authenticate(model)
            try request.set("skelpo-payload", to: payload)
            
            return model
        })
    }
    
    public static func authenticate(from body: AuthBody, on request: Request)throws -> Future<Self> {
        let futureUser = try Self.query(on: request).filter(Self.usernameKey == body.username).first().unwrap(or: Abort(.notFound, reason: "Username or password is incorrect"))
        
        return futureUser.map(to: (String, Self).self) { (found) in
            guard try BCrypt.verify(body.password, created: found.password) else {
                throw Abort(.unauthorized, reason: "Username or password is incorrect")
            }
            let token = try request.accessToken()
            return (token, found)
        }.map(to: Self.self) { (authenticated) in
            let jwt = try request.make(JWTService.self)
            let payload = try JWT<Payload>.init(from: Data(authenticated.0.utf8), verifiedUsing: jwt.signer).payload
            
            try request.set("skelpo-payload", to: payload)
            try request.authenticate(authenticated.1)
            
            return authenticated.1
        }
    }
}
