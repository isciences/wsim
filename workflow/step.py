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

class Step:
    def __init__(self, targets, dependencies, commands, comment=None):
        if type(targets) is str:
            targets = [targets]

        if type(dependencies) is str:
            dependencies = [dependencies]

        if len(targets) > 1:
            dependencies = [dep.replace('.', '%') for dep in dependencies]
            targets = [trg.replace('.', '%') for trg in targets]

        self.targets = targets
        self.dependencies = dependencies
        self.commands = [flatten(command) for command in commands]
        self.comment = comment

    def format_vars(self, txt, vars):
        try:
            return txt.format_map(vars)
        except (AttributeError, ValueError) as e:
            print("Failed to sub", txt, "in step for", self.targets)
            raise e

    def use_pattern_rules(self):
        # GNU Make only supports multiple targets when we use a pattern-style rule.
        # So we fake a patten by replacing our file extension with a %.
        return len(self.targets) > 1

    @classmethod
    def patternize(cls, filenames):
        return [filename.replace('.', '%') for filename in filenames]

    def target_string(self, keys):
        trgts = self.patternize(self.targets) if self.use_pattern_rules() else self.targets

        return ' '.join(self.format_vars(target, keys) for target in trgts)

    def dependency_string(self, keys):
        deps = self.dependencies if not self.use_pattern_rules() else [dep.replace('.', '%') for dep in self.dependencies]

        return ' '.join(self.format_vars(dep, keys) for dep in deps)

    @classmethod
    def target_separator(cls, use_order_only_rules):
        if use_order_only_rules:
            return ' : | '
        else:
            return ' : '

    def get_mkdir_commands(self):
        dirs = set([os.path.dirname(target) for target in self.targets])

        return [ ['mkdir', '-p', dir ] for dir in dirs if dir != '']

    def get_text(self, keys=None, use_order_only_rules=True):
        if keys is None:
            keys = {}
        txt = ""
        if self.comment:
            txt += "#" + self.comment + '\n'

        txt += self.target_string(keys) + self.target_separator(use_order_only_rules) + self.dependency_string(keys) + '\n'

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

