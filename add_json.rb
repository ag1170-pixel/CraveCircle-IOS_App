require 'xcodeproj'

project_path = 'AICookBook.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'AICookBook' }
group = project.main_group.find_subpath(File.join('AICookBook'), true)
file_ref = group.new_reference('BundledRecipes.json')

# Add to resources build phase
resources_phase = target.resources_build_phase
resources_phase.add_file_reference(file_ref, true)

project.save
puts "Added BundledRecipes.json to Xcode project"
