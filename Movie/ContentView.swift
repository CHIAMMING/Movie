
import SwiftUI
import CoreData
import URLImage

struct ContentView: View {
    var body: some View {
        TabView {
            MoviesListView()
                .tabItem {
                    Label("Movies", systemImage: "film")
                }

            UpcomingMoviesView()
                .tabItem {
                    Label("Upcoming", systemImage: "calendar")
                }
        }
    }
}

struct MoviesListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.title, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    @State private var trendingItems = [TrendingItem]()
    let gridItemLayout = [GridItem(.adaptive(minimum: 150))]
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            ScrollView {
                List {
                    ForEach(items, id: \.self) { item in
                        Text(item.releaseDate ?? "Untitled")
                    }
                }
                SearchBar(text: $searchText, placeholder: "Search movies")
                
                LazyVGrid(columns: gridItemLayout, spacing: 10) {
                    ForEach(filteredItems) { item in
                        NavigationLink(destination: MovieDetails(item: item)) {
                            VStack(alignment: .leading, spacing: 5) {
                                URLImage(URL(string: "https://image.tmdb.org/t/p/w500/\(item.posterPath ?? "")")!) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 170, height: CGFloat(calculateImageHeight(for: item.popularity)))
                                        .cornerRadius(10)
                                        .shadow(radius: 5)
                                }

                                Text(item.title ?? "Title Unavailable")
                                    .font(.system(size: 15))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .padding(.top, 5)

                                Text(item.releaseDate ?? "Release Date Unavailable")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            .padding(5)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Movies")
            .refreshable {
                fetchData()
            }
        }
        .onAppear(perform: fetchData)
    }

    var filteredItems: [TrendingItem] {
        if searchText.isEmpty {
            return trendingItems
        } else {
            return trendingItems.filter { $0.title?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

    func fetchData() {
        guard let url = URL(string: "https://api.themoviedb.org/3/trending/all/day?api_key=c389c459e4230537f937b948a7208ed7") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Invalid response")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            do {
                let decodedResponse = try JSONDecoder().decode(TrendingResponse.self, from: data)
                DispatchQueue.main.async {
                    self.trendingItems = decodedResponse.results
                    
                    // Save titles to Core Data
                    self.saveItemsToCoreData(decodedResponse.results)
                }
            } catch {
                print("Failed to decode response: \(error)")
            }
        }.resume()
    }

    func saveItemsToCoreData(_ items: [TrendingItem]) {
        let context = PersistenceController.shared.container.viewContext
        for item in items {
            let newItem = Item(context: context)
            newItem.title = item.title ?? "Title"
            newItem.overview = item.overview ?? "Overview"
            newItem.id = Int64(item.id)
            newItem.backdropPath = item.backdropPath ?? "backdropPath"
            newItem.popularity = item.popularity
            newItem.releaseDate = item.releaseDate ?? "releaseDate"
            newItem.voteAverage = item.voteAverage ?? 0.0
            newItem.voteCount = Int64(item.voteCount ?? 0)
        }
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
        }
    }

    func calculateImageHeight(for popularity: Double) -> Double {
        let minHeight = 150.0
        let maxHeight = 300.0
        let normalizedPopularity = min(max(popularity, 0), 100) / 100
        let height = minHeight + (maxHeight - minHeight) * normalizedPopularity
        return height
    }
}

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.trailing, 10)

            if !text.isEmpty {
                Button(action: {
                    withAnimation {
                        self.text = ""
                    }
                }) {
                    Image(systemName: "multiply.circle.fill")
                        .foregroundColor(Color(.systemGray))
                }
                .padding(.trailing, 10)
            }
        }
        .padding(.horizontal, 15)
    }
}

struct MovieDetails: View {
    let item: TrendingItem
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            URLImage(URL(string: "https://image.tmdb.org/t/p/w500/\(item.backdropPath ?? "")")!) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
            .padding(.bottom, 10)

            Text(item.title ?? "Unknown Title")
                .font(.title)
                .fontWeight(.bold)

            if let overview = item.overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .padding(.bottom, 10)
            }

            if let releaseDate = item.releaseDate {
                Text("Release Date: \(releaseDate)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
            }

            // Display the rating with stars
            if let voteAverage = item.voteAverage {
                let formattedVoteAverage = String(format: "%.1f", voteAverage / 2)
                let voteCount = item.voteCount ?? 0
                let ratingText = "Rating: \(formattedVoteAverage)/5 (\(voteCount) votes)"
                Text(ratingText)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
                // Display stars based on the vote average
                StarsView(voteAverage: voteAverage)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Details")
    }
}

// StarsView for displaying stars based on vote average
struct StarsView: View {
    let voteAverage: Double
    var body: some View {
            HStack {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= Int(voteAverage / 2.0) ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
            }
        }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

struct TrendingResponse: Decodable {
    let page: Int
    let results: [TrendingItem]
}

struct TrendingItem: Codable, Identifiable {
    let id: Int
    let adult: Bool
    let backdropPath: String?
    let title: String?
    let originalLanguage: String?
    let originalTitle: String?
    let overview: String?
    let posterPath: String?
    let mediaType: String?
    let genreIds: [Int]?
    let popularity: Double
    let releaseDate: String?
    let video: Bool?
    let voteAverage: Double?
    let voteCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, adult
        case backdropPath = "backdrop_path"
        case title, originalLanguage = "original_language", originalTitle = "original_title", overview
        case posterPath = "poster_path"
        case mediaType = "media_type"
        case genreIds = "genre_ids"
        case popularity, releaseDate = "release_date", video
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
}
