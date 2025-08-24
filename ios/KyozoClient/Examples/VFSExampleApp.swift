import SwiftUI
import KyozoClient

// MARK: - Example SwiftUI App using VFS

@main
struct KyozoVFSExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var client: KyozoClient?
    @State private var isAuthenticated = false
    @State private var selectedTeam: Team?
    @State private var selectedWorkspace: Workspace?
    
    var body: some View {
        NavigationStack {
            if !isAuthenticated {
                LoginView(isAuthenticated: $isAuthenticated, client: $client)
            } else if let client = client {
                if let workspace = selectedWorkspace, let team = selectedTeam {
                    VFSExplorerView(
                        client: client,
                        team: team,
                        workspace: workspace
                    )
                } else {
                    WorkspaceSelectionView(
                        client: client,
                        selectedTeam: $selectedTeam,
                        selectedWorkspace: $selectedWorkspace
                    )
                }
            }
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @Binding var isAuthenticated: Bool
    @Binding var client: KyozoClient?
    
    @State private var apiKey = ""
    @State private var baseURL = "http://localhost:4000/api/v1"
    
    var body: some View {
        Form {
            Section("API Configuration") {
                TextField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Base URL", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            
            Button("Connect") {
                connect()
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKey.isEmpty)
        }
        .navigationTitle("Connect to Kyozo")
        .padding()
    }
    
    private func connect() {
        guard let url = URL(string: baseURL) else { return }
        
        client = KyozoClient(baseURL: url, bearerToken: apiKey)
        isAuthenticated = true
    }
}

// MARK: - Workspace Selection

struct WorkspaceSelectionView: View {
    let client: KyozoClient
    @Binding var selectedTeam: Team?
    @Binding var selectedWorkspace: Workspace?
    
    @State private var teams: [Team] = []
    @State private var workspaces: [Workspace] = []
    @State private var isLoading = false
    
    var body: some View {
        List {
            Section("Select Team") {
                ForEach(teams) { team in
                    Button {
                        selectTeam(team)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(team.name)
                                if let description = team.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedTeam?.id == team.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            if selectedTeam != nil {
                Section("Select Workspace") {
                    ForEach(workspaces) { workspace in
                        Button {
                            selectedWorkspace = workspace
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(workspace.name)
                                    if let description = workspace.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedWorkspace?.id == workspace.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Workspace")
        .task {
            await loadTeams()
        }
        .refreshable {
            await loadTeams()
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }
    
    private func loadTeams() async {
        isLoading = true
        do {
            teams = try await client.teams.list()
        } catch {
            print("Failed to load teams: \(error)")
        }
        isLoading = false
    }
    
    private func selectTeam(_ team: Team) {
        selectedTeam = team
        Task {
            await loadWorkspaces(for: team)
        }
    }
    
    private func loadWorkspaces(for team: Team) async {
        isLoading = true
        do {
            workspaces = try await client.workspaces.list(teamId: team.id)
        } catch {
            print("Failed to load workspaces: \(error)")
        }
        isLoading = false
    }
}

// MARK: - VFS Explorer

struct VFSExplorerView: View {
    let client: KyozoClient
    let team: Team
    let workspace: Workspace
    
    @StateObject private var browser: VFSBrowser
    @State private var selectedFile: VFSFile?
    @State private var showingContent = false
    
    init(client: KyozoClient, team: Team, workspace: Workspace) {
        self.client = client
        self.team = team
        self.workspace = workspace
        self._browser = StateObject(wrappedValue: VFSBrowser(
            client: client,
            teamId: team.id,
            workspaceId: workspace.id
        ))
    }
    
    var body: some View {
        NavigationSplitView {
            VFSFileListView(browser: browser)
                .navigationTitle(workspace.name)
        } detail: {
            if let content = browser.selectedContent {
                VFSContentView(content: content)
            } else {
                ContentUnavailableView(
                    "Select a File",
                    systemImage: "doc.text",
                    description: Text("Choose a file from the sidebar to view its content")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Usage Examples

extension ContentView {
    /// Example: Create a markdown file and open it with VFS
    func createAndBrowseExample(client: KyozoClient, teamId: String, workspaceId: String) async {
        do {
            // Create a markdown file
            let file = try await client.files.create(
                teamId: teamId,
                request: .markdown(
                    name: "analysis.md",
                    title: "Data Analysis",
                    codeBlocks: [
                        (language: "python", code: """
                        import pandas as pd
                        df = pd.read_csv('data.csv')
                        print(df.head())
                        """),
                        (language: "sql", code: """
                        SELECT COUNT(*) as total_users
                        FROM users
                        WHERE created_at >= '2024-01-01'
                        """)
                    ]
                )
            )
            
            // List files with VFS - will include virtual guides
            let listing = try await client.vfs.list(
                teamId: teamId,
                workspaceId: workspaceId
            )
            
            print("Created file: \(file.name)")
            print("Total files (including virtual): \(listing.files.count)")
            
            // Find and read the guide.md virtual file
            if let guide = listing.files.first(where: { $0.name == "guide.md" && $0.virtual }) {
                let content = try await client.vfs.readContent(
                    teamId: teamId,
                    workspaceId: workspaceId,
                    path: guide.path
                )
                print("Guide content: \(content.content)")
            }
            
        } catch {
            print("Error: \(error)")
        }
    }
    
    /// Example: Working with project-specific virtual files
    func exploreProjectVirtualFiles(client: KyozoClient, teamId: String, workspaceId: String) async {
        do {
            let listing = try await client.vfs.list(
                teamId: teamId,
                workspaceId: workspaceId
            )
            
            // Group files by generator
            let filesByGenerator = Dictionary(grouping: listing.files.filter { $0.virtual }) { 
                $0.generator ?? "unknown"
            }
            
            for (generator, files) in filesByGenerator {
                print("\nFiles generated by \(generator):")
                for file in files {
                    print("  - \(file.name)")
                    
                    // Read content for deployment guides
                    if file.name.contains("deploy") {
                        let content = try await client.vfs.readContent(
                            teamId: teamId,
                            workspaceId: workspaceId,
                            path: file.path
                        )
                        print("    Deployment instructions found!")
                        print("    Preview: \(String(content.content.prefix(100)))...")
                    }
                }
            }
            
        } catch {
            print("Error exploring VFS: \(error)")
        }
    }
}