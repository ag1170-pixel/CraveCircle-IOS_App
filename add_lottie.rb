require 'xcodeproj'

project_path = 'AICookBook.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Lottie package URL
lottie_url = 'https://github.com/airbnb/lottie-spm.git'

# Check if package already exists
existing_package = project.root_object.package_references.find { |pkg| pkg.repositoryURL == lottie_url }

unless existing_package
  puts "Adding Lottie SPM..."
  
  # Add package reference
  package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  package.repositoryURL = lottie_url
  package.requirement = {
    'kind' => 'upToNextMajorVersion',
    'minimumVersion' => '4.5.0'
  }
  project.root_object.package_references << package

  # Find the main target
  target = project.targets.find { |t| t.name == 'AICookBook' }

  # Add package product dependency to the target
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.package = package
  dependency.product_name = 'Lottie'
  
  build_dependency = project.new(Xcodeproj::Project::Object::PBXTargetDependency)
  build_dependency.name = 'Lottie'
  build_dependency.product_ref = dependency
  
  target.dependencies << build_dependency
  
  project.save
  puts "Lottie added successfully."
else
  puts "Lottie already exists in project."
end
