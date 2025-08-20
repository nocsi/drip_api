defmodule KyozoWeb.LandingController do
  use KyozoWeb, :controller

  def index(conn, _params) do
    conn
    |> put_layout(false)
    |> put_root_layout(false)
    |> put_resp_content_type("text/html")
    |> send_resp(200, """
    <!DOCTYPE html>
    <html lang="en" class="min-h-full">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Kyozo - Literate Programming Reimagined</title>
      <script src="https://cdn.tailwindcss.com"></script>
      <style>
        .gradient-text {
          background: linear-gradient(to right, #2563eb, #9333ea);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
          background-clip: text;
        }
      </style>
    </head>
    <body class="min-h-full antialiased bg-gradient-to-br from-slate-50 to-white">
      <!-- Hero Section -->
      <section class="relative overflow-hidden">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-10 pb-24">
          <div class="text-center">
            <h1 class="text-5xl md:text-6xl font-bold text-gray-900 leading-tight">
              Literate Programming
              <span class="gradient-text">
                Reimagined
              </span>
            </h1>
            <p class="mt-8 text-xl text-gray-600 max-w-3xl mx-auto leading-relaxed">
              Create executable documents that combine code, documentation, and interactive visualizations.
              Transform your ideas into living, breathing documents that your team can understand and execute.
            </p>

            <div class="mt-10 flex flex-col sm:flex-row gap-4 justify-center">
              <a href="/auth/register" class="px-8 py-4 bg-blue-600 text-white rounded-lg text-lg font-semibold hover:bg-blue-700 transition-all transform hover:scale-105 shadow-lg">
                Start Writing →
              </a>
              <a href="/svelte" class="px-8 py-4 border-2 border-gray-300 text-gray-700 rounded-lg text-lg font-semibold hover:border-gray-400 transition-colors">
                Test Editor (Debug)
              </a>
            </div>
          </div>

          <!-- Hero Visual -->
          <div class="mt-20 relative">
            <div class="bg-white rounded-2xl shadow-2xl border border-gray-200 overflow-hidden">
              <div class="bg-gray-50 px-6 py-4 border-b border-gray-200 flex items-center space-x-2">
                <div class="w-3 h-3 bg-red-500 rounded-full"></div>
                <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
                <div class="w-3 h-3 bg-green-500 rounded-full"></div>
                <span class="ml-4 text-sm text-gray-500">my-analysis.kyozo</span>
              </div>
              <div class="p-8">
                <div class="space-y-6">
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                    <h3 class="text-lg font-semibold text-blue-900 mb-2"># Data Analysis Report</h3>
                    <p class="text-blue-700">
                      This document analyzes customer behavior patterns using machine learning.
                    </p>
                  </div>

                  <div class="bg-gray-100 border border-gray-300 rounded-lg p-4 font-mono text-sm">
                    <div class="text-gray-600 mb-2">```python</div>
                    <div class="text-purple-600">import pandas as pd</div>
                    <div class="text-purple-600">import matplotlib.pyplot as plt</div>
                    <div class="text-gray-900 mt-2">
                      # Load and analyze customer data<br>
                      df = pd.read_csv('customers.csv')<br>
                      plt.scatter(df['age'], df['spending'])
                    </div>
                    <div class="text-gray-600 mt-2">```</div>
                  </div>

                  <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                    <div class="flex items-center space-x-2 mb-2">
                      <div class="w-2 h-2 bg-green-500 rounded-full"></div>
                      <span class="text-green-800 font-medium">Executed successfully</span>
                    </div>
                    <div class="bg-white border rounded p-3">
                      <img src="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjEwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KICA8cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZjhmOWZhIi8+CiAgPGNpcmNsZSBjeD0iNTAiIGN5PSI1MCIgcj0iNCIgZmlsbD0iIzM3MzNlYSIvPgogIDxjaXJjbGUgY3g9IjgwIiBjeT0iMzAiIHI9IjQiIGZpbGw9IiMzNzMzZWEiLz4KICA8Y2lyY2xlIGN4PSIxMjAiIGN5PSI3MCIgcj0iNCIgZmlsbD0iIzM3MzNlYSIvPgogIDxjaXJjbGUgY3g9IjE1MCIgY3k9IjQwIiByPSI0IiBmaWxsPSIjMzczM2VhIi8+CiAgPHRleHQgeD0iMTAiIHk9IjkwIiBmb250LWZhbWlseT0iQXJpYWwsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTIiIGZpbGw9IiM2YjcyODAiPkN1c3RvbWVyIFNwZW5kaW5nIEFuYWx5c2lzPC90ZXh0Pgo8L3N2Zz4K" alt="Sample chart" class="w-full h-20 object-cover rounded">
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Features Section -->
      <section class="py-24 bg-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-16">
            <h2 class="text-3xl md:text-4xl font-bold text-gray-900 mb-4">
              Everything you need for literate programming
            </h2>
            <p class="text-xl text-gray-600 max-w-2xl mx-auto">
              Powerful tools to create, execute, and share your computational narratives.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div class="text-center p-6">
              <div class="w-16 h-16 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z"/>
                </svg>
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-2">Interactive Documents</h3>
              <p class="text-gray-600">Create documents that mix prose, code, and visualizations seamlessly.</p>
            </div>

            <div class="text-center p-6">
              <div class="w-16 h-16 bg-green-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                </svg>
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-2">Live Execution</h3>
              <p class="text-gray-600">Run code blocks and see results instantly within your document.</p>
            </div>

            <div class="text-center p-6">
              <div class="w-16 h-16 bg-purple-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3z"/>
                </svg>
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-2">Team Collaboration</h3>
              <p class="text-gray-600">Share, review, and collaborate on computational documents with your team.</p>
            </div>
          </div>
        </div>
      </section>

      <!-- CTA Section -->
      <section class="bg-blue-600 text-white py-16">
        <div class="max-w-4xl mx-auto text-center px-4 sm:px-6 lg:px-8">
          <h2 class="text-3xl md:text-4xl font-bold mb-4">
            Ready to revolutionize your workflow?
          </h2>
          <p class="text-xl mb-8 text-blue-100">
            Join thousands of developers, researchers, and teams already using Kyozo.
          </p>
          <div class="space-x-4">
            <a href="/auth/register" class="inline-block px-8 py-4 bg-white text-blue-600 rounded-lg text-lg font-semibold hover:bg-gray-50 transition-colors">
              Get Started Free
            </a>
            <a href="/svelte" class="inline-block px-8 py-4 border-2 border-white text-white rounded-lg text-lg font-semibold hover:bg-white hover:text-blue-600 transition-colors">
              Test Editor
            </a>
          </div>
        </div>
      </section>

      <!-- Footer -->
      <footer class="bg-gray-50 py-12">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center text-gray-600">
            <p>&copy; 2024 Kyozo. All rights reserved.</p>
          </div>
        </div>
      </footer>

      <!-- Simple Analytics -->
      <script>
        console.log('Kyozo landing page loaded successfully!');
        // Add your analytics tracking code here
      </script>
    </body>
    </html>
    """)
  end
end
