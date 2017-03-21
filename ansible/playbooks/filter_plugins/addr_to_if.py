def addr_to_if(addr, facts):
    for interface in facts['ansible_interfaces']:
        if not 'ipv4' in interface:
            continue

        if facts['ansible_{}'.format(interface)]['ipv4']['address'] == addr:
            return interface

    return None


class FilterModule(object):
    def filters(self):
        return {'addr_to_if': addr_to_if}
