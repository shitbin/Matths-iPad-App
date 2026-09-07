import Foundation
@MainActor enum DataScope {static var slot="A";static var directory:URL{URL(fileURLWithPath:"/unused-classwork-owner/"+slot)}}
struct Profile{var role:String?="teacher"}
@MainActor final class AppStore {
    struct AccountSessionBoundary:Equatable{var slot:String;var generation:Int}
    var generation=0
    var authProvider:String?="server"
    var serverProfile:Profile?=Profile()
    func captureAccountSessionBoundary()->AccountSessionBoundary{.init(slot:DataScope.slot,generation:generation)}
    func ownsCurrentAccountSession(_ value:AccountSessionBoundary)->Bool{value==captureAccountSessionBoundary()}
}
struct ServerAPIError:Error {var statusCode:Int?;var errorDescription:String?}
@MainActor enum ServerAPI {
    struct AuthorizationSnapshot{var token:String}
    struct AcademyClassSummary:Codable,Equatable{var id:String}
    static var token:String?="A"
    static var calls:[String]=[]
    static var postedKeys:[String]=[]
    static var hold=false,fail=false
    static var continuation:CheckedContinuation<Void,Never>?
    static var response:TeacherClasswork!
    static func captureAuthorization()->AuthorizationSnapshot?{token.map{.init(token:$0)}}
    static func isCurrentAuthorization(_ value:AuthorizationSnapshot)->Bool{token==value.token}
    static func reset(){token="A";calls=[];postedKeys=[];hold=false;fail=false;continuation=nil;DataScope.slot="A"}
    static func record(_ label:String,_ authorization:AuthorizationSnapshot)async throws {
        calls.append(label+":"+authorization.token)
        if hold{await withCheckedContinuation{continuation=$0}}
        if fail{throw ServerAPIError(statusCode:403,errorDescription:"controlled response")}
    }
    static func teacherAcademyClasswork(classID:String,authorization:AuthorizationSnapshot)async throws->TeacherClasswork{try await record("load",authorization);return response}
    static func saveTeacherAcademyClassWeek(classID:String,draft:TeacherClassWeekDraft,files:[URL],authorization:AuthorizationSnapshot)async throws->TeacherClasswork{
        postedKeys=draft.conceptKeys;try await record("save",authorization);return response
    }
    static func deleteTeacherAcademyClassWeek(classID:String,weekID:String,authorization:AuthorizationSnapshot)async throws->TeacherClasswork{try await record("delete",authorization);return response}
    static func removeTeacherAcademyClassWeekFile(classID:String,weekID:String,fileID:String,authorization:AuthorizationSnapshot)async throws->TeacherClasswork{try await record("remove",authorization);return response}
    static func downloadTeacherAcademyFile(classID:String,weekID:String,file:AcademyWeek.File,account:String,authorization:AuthorizationSnapshot)async throws->URL{try await record("preview",authorization);return URL(fileURLWithPath:"/unused-classwork-owner/private-preview.pdf")}
    static func release(){let value=continuation;continuation=nil;value?.resume()}
}
@main struct TeacherClassworkOwnerCases {
    @MainActor static func main()async throws {
        let concept=ServerAPI.AcademyWeek.Concept(curriculumId:"kr-2022",courseId:"common-math-1",courseTitle:"공통수학1",unitId:"polynomials",unitTitle:"다항식",conceptId:"polynomial-arithmetic",conceptTitle:"다항식의 사칙연산",href:nil)
        let key="common-math-1/polynomials/polynomial-arithmetic"
        let catalogConcept=ServerAPI.TeacherClassworkCatalogConcept(key:key,curriculumId:concept.curriculumId,courseId:concept.courseId,courseTitle:concept.courseTitle,unitId:concept.unitId,unitTitle:concept.unitTitle,conceptId:concept.conceptId,conceptTitle:concept.conceptTitle)
        let file=ServerAPI.AcademyWeek.File(id:"file-A",originalName:"test.pdf",mimeType:"application/pdf",sizeBytes:10)
        let week=ServerAPI.AcademyWeek(id:"week-A",academicYear:2026,weekNumber:1,title:"ORIGINAL",lessonSummary:"",concepts:[concept],assignmentTitle:"기존 과제",assignmentInstructions:"",dueAt:nil,files:[file])
        let base=ServerAPI.TeacherClasswork(academyClass:.init(id:"class-A"),currentAcademicYear:2026,weeks:[week],catalog:[.init(id:concept.courseId,title:concept.courseTitle,units:[.init(id:concept.unitId,title:concept.unitTitle,concepts:[catalogConcept])])])
        func fixture()->(AppStore,AccountRequestOwner,TeacherClassworkPanelModel){
            ServerAPI.reset();ServerAPI.response=base;ServerAPI.response.weeks[0].title="SERVER-RESPONSE"
            let store=AppStore(),model=TeacherClassworkPanelModel();let owner=AccountRequestOwner(store:store)!
            model.selectedClassID="class-A";model.classwork=base;model.edit(week)
            return(store,owner,model)
        }
        func perform(_ path:String,_ model:TeacherClassworkPanelModel,_ owner:AccountRequestOwner,_ store:AppStore)async {
            switch path{
            case "load":await model.load(owner:owner,store:store)
            case "save":await model.save(owner:owner,store:store)
            case "delete":await model.delete(week,owner:owner,store:store)
            case "remove":await model.removeFile(file,from:week,owner:owner,store:store)
            default:await model.preview(file,from:week,owner:owner,store:store)
            }
        }
        var checks=0
        for path in ["load","save","delete","remove","preview"] {
            for role in ["student","admin",""] {
                let(store,owner,model)=fixture()
                let queued=Task{@MainActor in await perform(path,model,owner,store)}
                store.serverProfile?.role=role.isEmpty ? nil:role
                await queued.value;precondition(ServerAPI.calls.isEmpty,"queued \(path) ran after role became \(role)");checks += 1
            }
            for failure in [false,true] {
                let(store,owner,model)=fixture();ServerAPI.hold=true;ServerAPI.fail=failure
                let pending=Task{@MainActor in await perform(path,model,owner,store)}
                for _ in 0..<20_000{if ServerAPI.continuation != nil{break};await Task.yield()}
                precondition(ServerAPI.continuation != nil)
                store.serverProfile?.role="student";ServerAPI.release();await pending.value
                precondition(ServerAPI.calls==[path+":A"])
                precondition(model.classwork==base && model.previewURL==nil && model.noticeMessage==nil && model.errorMessage==nil,"stale \(path) response/error applied after role revocation")
                checks += 1
            }
            do{
                let(store,owner,model)=fixture();await perform(path,model,owner,store)
                precondition(ServerAPI.calls==[path+":A"],"valid teacher \(path) must remain allowed");checks += 1
            }
        }
        do{
            let(store,owner,model)=fixture();store.authProvider=nil;await model.save(owner:owner,store:store)
            precondition(ServerAPI.calls.isEmpty);checks += 1
        }
        do{
            let(store,owner,model)=fixture()
            precondition(concept.id.contains("|") && !catalogConcept.key.contains("|"))
            precondition(model.selectedConceptKeys==[key] && model.draft.conceptKeys==[key],"editing must map UI identity to catalog selection key")
            await model.save(owner:owner,store:store)
            precondition(ServerAPI.postedKeys==[key],"existing-week save sent pipe identity instead of server key")
            checks += 1
        }
        do{
            let(_,_,model)=fixture()
            let catalog=(0..<220).map{index -> ServerAPI.TeacherClassworkCatalogConcept in
                var value=catalogConcept;value.key="known-key-\(index)";value.conceptTitle=String(format:"고유 개념 %03d",index);return value
            }
            model.classwork?.catalog[0].units[0].concepts=catalog
            for item in catalog{model.conceptSearch=item.conceptTitle;precondition(model.allConcepts.filter(model.matchesSearch).contains(where:{$0.key==item.key}));checks += 1}
        }
        print("Teacher classwork production model: \(checks) checks PASS (queued-role denial, post-await role success/error isolation, valid teacher, canonical edit/save key, 220-concept search)")
    }
}
