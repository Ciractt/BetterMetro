//
//  JourneyPlannerView.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//


// JourneyPlannerView.swift

import SwiftUI

struct JourneyPlannerView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack {
                Text("Journey Planner")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 50)
                
                Spacer(minLength: 20)
                
                VStack(spacing: 20) {
                    Text("Journey planning coming soon!")
                        .font(.headline)
                    
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
            .padding(.bottom, 90) // Make room for floating tab bar
        }
    }
}

struct JourneyPlannerView_Previews: PreviewProvider {
    static var previews: some View {
        JourneyPlannerView()
    }
}
