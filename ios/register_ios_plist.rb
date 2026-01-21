require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 1. Find the main target (Runner)
target = project.targets.find { |t| t.name == 'Runner' }

if target
  # 2. Add the file reference to the Runner group
  runner_group = project.main_group.find_subpath('Runner', true)
  file_ref = runner_group.find_file_by_path('GoogleService-Info.plist')
  
  unless file_ref
    file_ref = runner_group.new_file('GoogleService-Info.plist')
    puts "✅ Created file reference for GoogleService-Info.plist"
  else
    puts "ℹ️ File reference already exists"
  end

  # 3. Add to Copy Bundle Resources phase
  resources_phase = target.resources_build_phase
  unless resources_phase.files.any? { |f| f.file_ref.path == 'GoogleService-Info.plist' }
    resources_phase.add_file_reference(file_ref)
    puts "✅ Added GoogleService-Info.plist to Build Phase"
  else
    puts "ℹ️ File already in Build Phase"
  end

  # Save project
  project.save
  puts "🚀 Xcode project updated successfully"
else
  puts "❌ Could not find Runner target"
end
