import os

def flatten(lis):
    """Given a list, possibly nested to any level, return it flattened."""
    new_lis = []
    for item in lis:
        if type(item) == type([]):
            new_lis.extend(flatten(item))
        else:
            new_lis.append(item)
    return new_lis

def format_vars(txt, vars):
    try:
        return txt.format_map(vars)
    except (AttributeError, ValueError) as e:
        print("Failed to sub ", txt)
        raise e

class Step:
    def __init__(self, targets, dependencies, commands, comment=None):
        if type(targets) is str:
            targets = [targets]

        if type(dependencies) is str:
            dependencies = [dependencies]

        # GNU Make only supports multiple targets when we use a pattern-style rule.
        # So we fake a patten by replacing our file extension with a %.
        if len(targets) > 1:
            dependencies = [dep.replace('.', '%') for dep in dependencies]
            targets = [trg.replace('.', '%') for trg in targets]

        self.target = targets
        self.dependencies = dependencies
        self.commands = [flatten(command) for command in commands]
        self.comment = comment

    def targetString(self, vars):
        return ' '.join(format_vars(target, vars) for target in self.target)

    def get_mkdir_commands(self):
        dirs = set([os.path.dirname(target) for target in self.target])

        return [ ['mkdir', '-p', dir ] for dir in dirs ]

    def get_text(self, keys=None):
        if keys is None:
            keys = {}
        txt = ""
        if self.comment:
            txt += "#" + self.comment + '\n'

        txt += self.targetString(keys) + ' : ' + ' '.join(format_vars(dep, keys) for dep in self.dependencies) + '\n'

        for command in self.get_mkdir_commands() + self.commands:
            for i in range(len(command)):
                if command[i].startswith('-'):
                    command[i-1] += ' \\'

            txt += '\t'
            for token in command:
                try:
                    txt += token.format_map(keys)
                except Exception as e:
                    print("Error subbing", token)
                    print(keys)
                    print(e)
                    raise
                if token.endswith('\\'):
                    txt += '\n\t   '
                else:
                    txt += ' '

            txt += '\n'
        return txt + '\n'

