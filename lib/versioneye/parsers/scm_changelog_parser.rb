require 'versioneye/parsers/common_parser'

class ScmChangelogParser < CommonParser


  def parse content, token = nil
    return nil if content.to_s.empty?
    return nil if content.to_s.strip.eql?('Not Found')

    entries = []
    doc = fetch_xml( content )
    base = nil
    base_nodes = doc.xpath('//changelog/revision_base')
    base = base_nodes.first.text.strip if base_nodes && !base_nodes.empty?
    doc.xpath('//changeset/changelog-entry').each do |node|
      changelog = ScmChangelogEntry.new
      parse_changelog_entry node, changelog
      changelog.revision_base = base
      entries << changelog
    end
    entries
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def parse_changelog_entry node, changelog
    dt = ''
    node.children.each do |child|
      if child.name.casecmp('msg') == 0
        changelog.message = child.text.strip
      elsif child.name.casecmp('date') == 0
        dt = "#{dt}#{child.text.strip}"
      elsif child.name.casecmp('time') == 0
        dt = "#{dt} #{child.text.strip}"
      elsif child.name.casecmp('author') == 0
        changelog.author = child.text.strip
      elsif child.name.casecmp('file') == 0
        child.children.each do |ch|
          if ch.name.casecmp('action') == 0
            changelog.action = ch.text.strip
          elsif ch.name.casecmp('name') == 0
            changelog.file = ch.text.strip
          elsif ch.name.casecmp('revision') == 0
            changelog.revision = ch.text.strip
          end
        end
      end
    end
    changelog.change_date = DateTime.parse dt
    changelog
  end


end
