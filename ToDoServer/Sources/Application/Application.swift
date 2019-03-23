import Foundation
import Kitura
import LoggerAPI
import Configuration
import CloudEnvironment
import KituraContracts
import Health
import KituraOpenAPI
import KituraCORS
import Dispatch
import SwiftKueryORM
import SwiftKueryPostgreSQL

public let projectPath = ConfigurationManager.BasePath.project.path
public let health = Health()

public class App {
    let router = Router()
    let cloudEnv = CloudEnv()
    // on memory
    //    private var todoStore: [ToDo] = []
    private var nextId: Int = 0
    //    private let workerQueue = DispatchQueue(label: "worker")
    
    public init() throws {
        // Run the metrics initializer
        initializeMetrics(router: router)
    }
    
    func postInit() throws {
        Persistence.setUp()
        
        do {
            try ToDo.createTableSync()
        } catch let error {
            print("Table already exists. Error: \(String(describing: error))")
        }
        
        // 全てのoriginを許可
        let options = Options(allowedOrigin: .all)
        // optionsをセットして、routerに与える
        let cors = CORS(options: options)
        router.all("/*", middleware: cors)
        
        /*
         public func post<I: Codable, O: Codable>(_ route: String, handler: @escaping CodableClosure<I, O>) {
         postSafely(route, handler: handler)
         }
         */
        router.post("/", handler: storeHandler)
        router.delete("/", handler: deleteAllHandler)
        router.get("/", handler: getAllHandler)
        router.get("/", handler: getOneHandler)
        // PATCH PUTと非常ににているが、若干異なる。両方Kituraでさポーとしている
        router.patch("/", handler: updateHandler)
        router.delete("/", handler: deleteOneHandler)
        
        // Endpoints
        initializeHealthRoutes(app: self)
        KituraOpenAPI.addEndpoints(to: router)
    }
    
    // on memory
    //    func execute(_ block: @escaping () -> Void) {
    //        workerQueue.async {
    //            block()
    //        }
    //    }
    
    func getOneHandler(id: Int, completion: @escaping (ToDo?, RequestError?) -> Void) {
        ToDo.find(id: id, completion)
        // on memory
        //        guard let todo = todoStore.first(where: { $0.id == id }) else {
        //            return completion(nil, .notFound)
        //        }
        //        completion(todo, nil)
    }
    
    func getAllHandler(completion: @escaping ([ToDo]?, RequestError?) -> Void ) {
        ToDo.findAll(completion)
        // on memory
        //        completion(todoStore, nil)
    }
    
    func storeHandler(todo: ToDo, completion: @escaping (ToDo?, RequestError?) -> Void ) {
        var todo = todo
        if todo.completed == nil {
            todo.completed = false
        }
        todo.id = nextId
        todo.url = "http://localhost:8080/\(nextId)"
        nextId += 1
        todo.save(completion)
        // on memory
        //        execute {
        //            self.todoStore.append(todo)
        //        }
        //        completion(todo, nil)
    }
    
    func deleteOneHandler(id: Int, completion: @escaping (RequestError?) -> Void) {
        ToDo.delete(id: id, completion)
        // on memory
        //        execute {
        //            self.todoStore.remove(at: index)
        //        }
        //        completion(nil)
    }
    
    func deleteAllHandler(completion: @escaping (RequestError?) -> Void) {
        ToDo.deleteAll(completion)
        // on memory
        //        execute {
        //            self.todoStore = []
        //        }
        //        completion(nil)
    }
    
    func updateHandler(id: Int, new: ToDo, completion: @escaping (ToDo?, RequestError?) -> Void ) {
        ToDo.find(id: id) { (preExistingToDo, error) in
            if error != nil {
                return completion(nil, .notFound)
            }
            guard var oldToDo = preExistingToDo else {
                return completion(nil, .notFound)
            }
            guard let id = oldToDo.id else {
                return completion(nil, .internalServerError)
            }
            oldToDo.user = new.user ?? oldToDo.user
            oldToDo.order = new.order ?? oldToDo.order
            oldToDo.title = new.title ?? oldToDo.title
            oldToDo.completed = new.completed ?? oldToDo.completed
            
            oldToDo.update(id: id, completion)
        }
        // on memory
        //        // find todo
        //        guard let index = todoStore.index(where: { $0.id == id }) else {
        //            return completion(nil, .notFound)
        //        }
        //
        //        // update todo
        //        var current = todoStore[index]
        //        current.user = new.user ?? current.user
        //        current.order = new.order ?? current.order
        //        current.title = new.title ?? current.title
        //        current.completed = new.completed ?? current.completed
        //        execute {
        //            self.todoStore[index] = current
        //        }
        //        // return todo
        //        completion(current, nil)
    }
    
    public func run() throws {
        try postInit()
        Kitura.addHTTPServer(onPort: cloudEnv.port, with: router)
        Kitura.run()
    }
}

extension ToDo: Model {
}

class Persistence {
    
    private init() { }
    
    static func setUp() {
        let pool = PostgreSQLConnection.createPool(
            // localのkurbenetesの中のDNSが設定している。helmを使うと名前を指定できて簡単。
            host: "postgresql-database",
            port: 5432,
            options: [
                .databaseName("tododb"),
                .password(ProcessInfo.processInfo.environment["DBPASSWORD"] ?? "nil"),
                .userName("postgres")],
            poolOptions: ConnectionPoolOptions(initialCapacity: 10, maxCapacity: 50))
        
        Database.default = Database(pool)
    }
}




