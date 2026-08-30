//
//  SettingView.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/19.
//

import OSLog
import SwiftUI
import CoreData

struct SettingView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var managedObjectContext
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    @State private var isConfirmingDelete = false
    @State private var isConfirmingDeleteAgain = false

    #if DEBUG
    @State private var schemaState = CloudKitSchemaState.idle
    #endif

    var body: some View {
        List {
            defaultSetting
            feedbackAndQuestion
            appVersionCheck
            #if DEBUG
            cloudKitSchema
            #endif
            deleteAll
        }
        .alert("모든 데이터를 삭제할까요?", isPresented: $isConfirmingDelete) {
            Button("취소", role: .cancel) { }
            Button("계속", role: .destructive) { isConfirmingDeleteAgain = true }
        } message: {
            Text("여행·지출·예산·영수증 사진이 모두 지워집니다.")
        }
        // 되돌릴 수 없고 iCloud 로 다른 기기까지 함께 지워지므로 한 번 더 묻는다.
        // 첫 알림에서 손이 미끄러진 경우를 여기서 잡는다.
        .alert("정말 지울까요?", isPresented: $isConfirmingDeleteAgain) {
            Button("취소", role: .cancel) { }
            Button("모두 삭제", role: .destructive, action: deleteAllData)
        } message: {
            Text("이 동작은 되돌릴 수 없습니다.\niCloud 로 연결된 다른 기기에서도 함께 지워집니다.\n\n남겨야 할 기록이 있다면 영수증 탭에서 CSV 로 먼저 내보내세요.")
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("설정")
        .navigationBarBackButtonHidden(true)
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Image(systemName: "chevron.left")
                })
            }
        }
    }
    
    private var defaultSetting: some View {
        Section {
            listButton(title: String(localized: "위치 설정"), target: UIApplication.openSettingsURLString)
            listButton(title: String(localized: "마이크 설정"), target: UIApplication.openSettingsURLString)
        } header: {
            Text("기본 설정")
                .font(.caption2)
                .foregroundStyle(.gray400) // 피그마에 확정 되지 않은 부분
        }
    }
    
    private var feedbackAndQuestion: some View {
        Section {
            listButton(title: String(localized: "버그 신고 및 피드백"), target: "mailto:eunkwanbear@gmail.com")
        } header: {
            Text("피드백 및 문의사항")
                .font(.caption2)
                .foregroundStyle(.gray400)
        }
    }

    private var appVersionCheck: some View {
        Section {
            HStack(spacing: 0) {
                Text("앱 버전")
                    .font(.caption3)
                    .foregroundStyle(.black)
                Spacer()
                Text(appVersion ?? "-")
                    .font(.body1)
                    .foregroundStyle(.gray400)
            }
        } header: {
            Text("앱 정보")
                .font(.caption2)
                .foregroundStyle(.gray400)
        }
    }
    
    #if DEBUG
    // 개발 빌드에만 둔다. CloudKit 은 스키마를 스스로 만들지 않아, 모델에 적힌
    // 것을 한 번 올려 두지 않으면 쓰지 않은 필드가 영영 만들어지지 않는다.
    // 그 상태로 운영에 올리면 다른 기기에서 그 필드만 조용히 비어 온다.
    private var cloudKitSchema: some View {
        Section {
            Button {
                deploySchema()
            } label: {
                HStack {
                    Text("CloudKit 스키마 올리기")
                        .font(.caption3)
                        .foregroundStyle(schemaState.isRunning ? .gray300 : .black)
                    Spacer()
                    if schemaState.isRunning {
                        ProgressView()
                    }
                }
            }
            .disabled(schemaState.isRunning)

            if let message = schemaState.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(schemaState.isFailure ? .red : Color.mainAccent)
            }
        } header: {
            Text("개발용")
        } footer: {
            Text("모델에 적힌 엔티티·속성을 CloudKit 개발 환경에 올립니다. 유료 개발자 계정으로 서명하고 iCloud 에 로그인한 기기에서만 됩니다.\n\n올린 뒤 CloudKit Dashboard 에서 개발 → 운영으로 승격해야 실제 사용자에게 적용됩니다. 승격은 되돌릴 수 없어 여기서 하지 않습니다.")
                .font(.caption2)
                .foregroundStyle(.gray400)
        }
    }

    private func deploySchema() {
        schemaState = .running
        // 모델 전체를 올리느라 몇 초 걸린다. 메인을 붙잡지 않는다.
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try PersistenceController.shared.deployCloudKitSchema()
                }.value
                schemaState = .succeeded
            } catch {
                schemaState = .failed(error.localizedDescription)
            }
        }
    }
    #endif

    private var deleteAll: some View {
        Section {
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Text("모든 데이터 삭제하기")
                    .font(.caption3)
                    .foregroundStyle(.red)
            }
        } footer: {
            Text("여행·지출·예산이 모두 지워집니다. 되돌릴 수 없습니다.")
                .font(.caption2)
                .foregroundStyle(.gray400)
        }
    }
    
    private var chevronRight: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 16))
            .foregroundStyle(.gray300)
    }
    
    private func listButton(title: String, target: String) -> some View {
        return Button(action: {
            if let url = URL(string: target) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }, label: {
            HStack(spacing: 0) {
                Text("\(title)")
                    .font(.caption3)
                    .foregroundStyle(.black)
                Spacer()
                chevronRight
                
            }
        })
    }
    
    // 지출·예산은 여행에 딸린 자식이라 부모보다 먼저 지운다.
    // 예전 목록에는 Budget 이 빠져 있어 여행만 지우면 예산이 고아로 남았다.
    //
    // NSBatchDeleteRequest 도 걷어냈다. 저장소를 직접 쳐서 viewContext 와
    // CloudKit 미러링이 변경을 보지 못하기 때문에, 동기화를 켠 지금은 지운 데이터가
    // 다른 기기에서 되살아난다. 컨텍스트를 통해 지워야 변경 이력이 함께 전파된다.
    // 삭제량이 크지 않아 성능 손해는 없다.
    private func deleteAllData() {
        let entities = ["Expense", "Budget", "Travel", "User"]
        do {
            for entity in entities {
                let request = NSFetchRequest<NSManagedObject>(entityName: entity)
                request.includesPropertyValues = false
                for object in try managedObjectContext.fetch(request) {
                    managedObjectContext.delete(object)
                }
            }
            try managedObjectContext.save()
        } catch {
            Logger.data.error("전체 삭제 실패: \(error.localizedDescription, privacy: .public)")
            managedObjectContext.rollback()
        }
    }
}

#Preview {
    SettingView()
}

#if DEBUG
/// CloudKit 스키마 올리기의 진행 상태.
enum CloudKitSchemaState {
    case idle
    case running
    case succeeded
    case failed(String)

    var isRunning: Bool { if case .running = self { return true } else { return false } }
    var isFailure: Bool { if case .failed = self { return true } else { return false } }

    var message: String? {
        switch self {
        case .idle:
            return nil
        case .running:
            return "올리는 중입니다. 모델 전체를 올리므로 몇 초 걸립니다."
        case .succeeded:
            return "올렸습니다. CloudKit Dashboard 에서 개발 → 운영으로 승격하세요."
        case .failed(let reason):
            return "실패: \(reason)"
        }
    }
}
#endif
