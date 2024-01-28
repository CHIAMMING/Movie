import SwiftUI
import URLImage

struct UpcomingMovieResponse: Decodable {
    let page: Int
    let results: [UpcomingMovie]
}

struct UpcomingMovie: Codable, Identifiable {
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

struct UpcomingMoviesView: View {
    @State private var movies: [UpcomingMovie] = []
    
    var body: some View {
        ScrollView {
            LazyVStack {
                Text("Upcoming Movies")
                    .font(.largeTitle)
                    .padding()
                
                ForEach(movies) { movie in
                    VStack(alignment: .leading) {
                        // Display the backdrop image on top of the title
                        URLImage(URL(string: "https://image.tmdb.org/t/p/w500/\(movie.backdropPath ?? "")")!) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200) // Adjust the height as needed
                        }
                        
                        Text(movie.title ?? "Unknown Title")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Text("Release Date: \(movie.releaseDate ?? "Unknown Date")")
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .onAppear {
                fetchUpcomingMovies()
            }
        }
    }
    
    func fetchUpcomingMovies() {
        // API URL
        guard let url = URL(string: "https://api.themoviedb.org/3/movie/upcoming?api_key=c389c459e4230537f937b948a7208ed7") else {
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
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let decodedResponse = try decoder.decode(UpcomingMovieResponse.self, from: data)
                
                DispatchQueue.main.async {
                    let currentDate = Date()
                    self.movies = decodedResponse.results.filter { movie in
                        guard let releaseDateString = movie.releaseDate,
                              let releaseDate = ISO8601DateFormatter().date(from: releaseDateString) else {
                            return true
                        }
                        return releaseDate > currentDate
                    }
                }
            } catch {
                print("Failed to decode response: \(error)")
            }
        }.resume()
    }
}

struct UpcomingMoviesView_Previews: PreviewProvider {
    static var previews: some View {
        UpcomingMoviesView()
    }
}
