//
//  ModelManager.swift
//  CoreData
//
//  Created by Diego Prados on 13/08/14.
//  Copyright (c) 2014 Diego Prados. All rights reserved.
//

import Foundation
import CoreData

let kCoreDataUpdated: String = "coreDataUpdated"

class ModelManager: NSObject {
    
    // MARK: - Singleton init
    
    struct Static {
        static var token : dispatch_once_t = 0
        static var instance : ModelManager?
    }
    
    class var instance: ModelManager {
    dispatch_once(&Static.token) {  Static.instance = ModelManager() }
        return Static.instance!
    }
    
    override init () {
        assert(Static.instance == nil, "Singleton already initialized!")
    }
    
    // MARK: - CoreData methods

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.dprados.CoreDataSpike" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] as NSURL
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("yourDataModelName", withExtension: "momd")
        return NSManagedObjectModel(contentsOfURL: modelURL!)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        
        // iCloud notification subscriptions
        var notificacionCenter: NSNotificationCenter = NSNotificationCenter.defaultCenter()
        notificacionCenter.addObserver(self, selector: "storesWillChange:", name:NSPersistentStoreCoordinatorStoresWillChangeNotification, object: coordinator)
        notificacionCenter.addObserver(self, selector: "storesDidChange:", name:NSPersistentStoreCoordinatorStoresDidChangeNotification, object: coordinator)
        notificacionCenter.addObserver(self, selector: "persistentStoreDidImportUbiquitousContentChanges:", name:NSPersistentStoreDidImportUbiquitousContentChangesNotification, object: coordinator)
        
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("yourDataModelName.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        var options: NSDictionary = [NSMigratePersistentStoresAutomaticallyOption : NSNumber(bool: true), NSInferMappingModelAutomaticallyOption : NSNumber(bool: true),
            NSPersistentStoreUbiquitousContentNameKey : "inGameStatsHoopsCloudStore"]
        if coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: options, error: &error) == nil {
            coordinator = nil
            // Report any error we got.
            let dict = NSMutableDictionary()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(error), \(error!.userInfo)")
            abort()
        }
        
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    // MARK: - Methods
    
    func startModel() {
        let moc = self.managedObjectContext
    }

    // MARK: - Core Data Saving support

    func saveContext () {
        if let moc = self.managedObjectContext {
            var error: NSError? = nil
            if moc.hasChanges && !moc.save(&error) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog("Unresolved error \(error), \(error!.userInfo)")
                abort()
            }
        }
    }
    
    // MARK: - Core Data discard changes
    
    func discardChanges() {
        self.managedObjectContext?.rollback()
    }
    
    // MARK: - iCloud Notifications
    
    func persistentStoreDidImportUbiquitousContentChanges(notification: NSNotification) {
        println(notification.userInfo?.description)
        var moc: NSManagedObjectContext = self.managedObjectContext!
        moc.performBlock { () -> Void in
            moc.mergeChangesFromContextDidSaveNotification(notification)
            var changes: NSDictionary = notification.userInfo!
            var allChanges: NSMutableSet = NSMutableSet()
            allChanges.unionSet(changes.valueForKey(NSInsertedObjectsKey) as NSSet)
            allChanges.unionSet(changes.valueForKey(NSUpdatedObjectsKey) as NSSet)
            allChanges.unionSet(changes.valueForKey(NSDeletedObjectsKey) as NSSet)
        }
        NSNotificationCenter.defaultCenter().postNotificationName(kCoreDataUpdated, object: self)
    }
   
    func storesWillChange(notification: NSNotification) {
        var moc: NSManagedObjectContext = self.managedObjectContext!
        moc.performBlockAndWait { () -> Void in
            var error: NSError?
            if moc.hasChanges {
                moc.save(&error)
            }
            moc.reset()
        }
    }

    func storesDidChange(notification: NSNotification) {
        // here is when you can refresh your UI and
        // load new data from the new store
    }

    // MARK: - Object creation

    func insertNewEntityName (entityName: String) -> AnyObject {
        return NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: self.managedObjectContext!);
    }

    // MARK: - Object deletion

    func deleteObject(object:NSManagedObject) {
        self.managedObjectContext?.deleteObject(object)
    }

    // MARK: - Object search

    func fetchEntity(entityName: String, identifier: String?, managedObjectContext: NSManagedObjectContext) -> AnyObject? {
        var predicate: NSPredicate?
        if identifier != nil {
            predicate = NSPredicate(format: "identifier == %@", identifier!)
        }
        let results: [AnyObject]? = self.fetchEntities(entityName, predicate: predicate, sortDescriptors: [], fetchLimit: 1, context: self.managedObjectContext!)
        var result: AnyObject? = nil
        if results?.count > 0 {
            result = results?[0]
        }
        return result
    }
    
    func fetchEntity(entityName: String, identifier: NSNumber) -> AnyObject? {
        return self.fetchEntity(entityName, identifier: identifier);
    }
    
    func fetchEntities(entityName: String) -> [AnyObject]? {
        return self.fetchEntities(entityName, predicate: nil, sortDescriptors: nil, fetchLimit: 0)
    }
    
    func fetchEntities(entityName: String, predicate: NSPredicate?) -> [AnyObject]? {
        return self.fetchEntities(entityName, predicate: predicate, sortDescriptors: nil, fetchLimit: 0)
    }
    
    func fetchEntities(entityName: String, predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, fetchLimit: Int) -> [AnyObject]? {
        return self.fetchEntities(entityName, predicate: predicate, sortDescriptors: sortDescriptors, fetchLimit: fetchLimit, context: self.managedObjectContext!)
    }
    
    func fetchEntities(entityName: String, predicate: NSPredicate?, sortKey: String?, fetchLimit: Int) -> [AnyObject]? {
        var sortDescriptors: [NSSortDescriptor]? = nil
        if sortKey != nil {
            sortDescriptors = [NSSortDescriptor(key: sortKey!, ascending: true)]
        }
        return self.fetchEntities(entityName, predicate: predicate, sortDescriptors: sortDescriptors, fetchLimit: fetchLimit)
    }

    func fetchEntities(entityName: String, predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, fetchLimit: Int, context: NSManagedObjectContext!) -> [AnyObject]! {
        var fetchRequest: NSFetchRequest! = NSFetchRequest(entityName: entityName)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        if fetchLimit != 0 {
            fetchRequest.fetchLimit = fetchLimit
        }
        var error: NSError? = nil
        var results = context.executeFetchRequest(fetchRequest, error: &error)
        if error != nil {
            println("Error fetching entity \(entityName): \(error), \(error?.userInfo)")
        }
        return results
    }
    
}