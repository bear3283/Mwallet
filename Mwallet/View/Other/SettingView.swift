//
//  SettingView.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/19.
//

import SwiftUI
import CoreData

struct SettingView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var managedObjectContext
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    var body: some View {
        List {
            defaultSetting
            feedbackAndQuestion
            appVersionCheck
            //            deleteAll
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
            listButton(title: "위치 설정", target: UIApplication.openSettingsURLString)
            listButton(title: "마이크 설정", target: UIApplication.openSettingsURLString)
        } header: {
            Text("기본 설정")
                .font(.caption2)
                .foregroundStyle(.gray400) // 피그마에 확정 되지 않은 부분
        }
    }
    
    private var feedbackAndQuestion: some View {
        Section {
            listButton(title: "버그 신고 및 피드백", target: "mailto:eunkwanbear@gmail.com")
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
    
    private var deleteAll: some View {
        Section {
            Button {
                deleteAllData()
            } label: {
                HStack(spacing: 0) {
                    Text("모든 데이터 삭제하기")
                        .font(.caption3)
                        .foregroundStyle(.red)
                }
            }
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
            print("SettingView | 전체 삭제 실패: \(error.localizedDescription)")
            managedObjectContext.rollback()
        }
    }
}

#Preview {
    SettingView()
}
