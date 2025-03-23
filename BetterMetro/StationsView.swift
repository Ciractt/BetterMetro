//
//  StationsView.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//


// StationsView.swift

import SwiftUI

struct StationsView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack {
                Text("Stations")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 50)
                
                Spacer(minLength: 20)
                
                VStack(spacing: 20) {
                    Text("Station search coming soon!")
                        .font(.headline)
                    
                    Image(systemName: "train.side.front.car")
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

struct StationsView_Previews: PreviewProvider {
    static var previews: some View {
        StationsView()
    }
}
