#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'NavApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'NavApp' }

# Add Carthage frameworks
frameworks = [
  'Carthage/Build/iOS/Nbmap.framework',
  'Carthage/Build/iOS/Turf.framework', 
  'Carthage/Build/iOS/NbmapCoreNavigation.framework',
  'Carthage/Build/iOS/NbmapNavigation.framework'
]

frameworks.each do |framework_path|
  # Add framework reference
  framework_ref = project.main_group.new_reference(framework_path)
  framework_ref.source_tree = 'SOURCE_ROOT'
  
  # Add to target
  target.frameworks_build_phase.add_file_reference(framework_ref)
  
  # Add to "Embed Frameworks" phase if it exists, or create it
  embed_phase = target.copy_files_build_phases.find { |phase| phase.name == 'Embed Frameworks' }
  if embed_phase.nil?
    embed_phase = target.new_copy_files_build_phase('Embed Frameworks')
    embed_phase.dst_subfolder_spec = :frameworks
  end
  embed_phase.add_file_reference(framework_ref)
end

# Save the project
project.save

puts "Successfully added Carthage frameworks to Xcode project"
