#!/usr/bin/env python3
"""Replace magic memory addresses with named variables in SargonII.S"""
import re, sys

# ── Variable definitions to INSERT at top of file ──────────────────────
NEW_EQUATES = """\
; Zero page - Input/display
input_buf_idx =  $00            ; input buffer write position
str_ptr      =   $05            ; string pointer low (str_ptr+1=$06)
joystick_flag =  $1f            ; joystick mode / move phase flag
display_pos  =   $f9            ; input display position counter

; Zero page - Board squares
cur_square   =   $07            ; from-square / cursor position
target_sq    =   $08            ; to-square / rook destination
castle_dir   =   $09            ; castling step direction / temp
hint_to_sq   =   $0a            ; hint to-square / exchange temp
move_from    =   $0b            ; move from (persists across make/unmake)
move_to      =   $0c            ; move to (persists across make/unmake)

; Zero page - Move generation temps (heavily reused)
piece_type   =   $0d            ; piece type / move flags
target_type  =   $0e            ; target piece / distance / score
dir_index    =   $0f            ; direction index / bonus / sort pos
dir_count    =   $10            ; direction count / defender cnt / sort
step_delta   =   $11            ; step offset / list position / sort
ray_flags    =   $12            ; ray flags / exchange cnts / side toggle
cur_piece    =   $13            ; current piece byte (bit7=color)
target_piece =   $14            ; piece at target square / capture temp

; Zero page - Game state flags
book_status  =   $1c            ; opening book exhausted flag
legal_found  =   $1d            ; flag: legal move found in search
opening_bonus =  $1e            ; positional strategy bonus

; Zero page - Evaluation
score_lo     =   $61            ; evaluation score low byte
score_hi     =   $62            ; evaluation score high byte
best_exchange =  $63            ; best own exchange gain
best_threat  =   $64            ; best enemy threat value
second_threat =  $65            ; second-best enemy threat
exchange_sq  =   $66            ; exchange target square flag
mobility_bal =   $67            ; mobility balance accumulator
positional   =   $68            ; positional/centrality score
check_flag   =   $69            ; attacking enemy king flag
material_bal =   $6a            ; material balance (white-black)
pawn_score   =   $6b            ; pawn structure score
king_pos     =   $6c            ; king positions (+0=white, +1=black)
def_list_ptr =   $6e            ; defender list pointer (grows down)
atk_list_ptr =   $6f            ; attacker list pointer (grows up)
node_count_lo =  $70            ; search node counter low
node_count_hi =  $71            ; search node counter high

; Zero page - Search engine
move_list_ptr =  $8b            ; move list base pointer (low; +1=high)
move_index   =   $8d            ; current move index in move list
alloc_ptr    =   $8e            ; move list alloc pointer (low; +1=high)
book_code    =   $9c            ; opening book move code
prev_best    =   $9f            ; previous iteration best from-square

; Zero page - Graphics/display
screen_ptr   =   $a3            ; screen RAM pointer (low; +1=high)
gfx_index    =   $a5            ; piece graphics index
piece_stripped = $a7            ; piece byte with has-moved cleared
flash_count  =   $a8            ; flash counter
square_color =   $a9            ; square color ($00=light, $80=dark)
piece_byte   =   $aa            ; raw piece byte from board
file_col     =   $ab            ; file/column coordinate (0-7)
rank_row     =   $ac            ; rank/row coordinate (0-7)
dest_file    =   $ad            ; destination file for animation
dest_rank    =   $ae            ; destination rank for animation
prev_hint_to =   $b4            ; previous hint to-square
ply2_from    =   $b5            ; ply-2 best from-square
ply2_to      =   $b6            ; ply-2 best to-square
color_ptr    =   $f7            ; color RAM pointer (low; +1=high)

; RAM - Game data structures
pv_buffer    =   $1000          ; principal variation buffer
move_list    =   $1001          ; root move list base
input_buf    =   $0200          ; joystick input buffer
notation_buf =   $033c          ; input/notation buffer (6 bytes)
move_history =   $12fe          ; move history buffer (34 bytes)
exch_packed  =   $1319          ; static exchange packed table
capture_stk  =   $1327          ; per-ply captured piece stack
captured     =   $1328          ; captured piece at current move
flags_stk    =   $1331          ; per-ply move flags stack
move_flags   =   $1332          ; move flags at current move
ply_idx_stk  =   $133b          ; per-ply move index stack
exch_squares =   $1346          ; exchange target square list
exch_sources =   $13c6          ; exchange source square list
killer_from  =   $1445          ; killer from-squares per ply
killer_to    =   $144f          ; killer to-squares per ply
ply_list_lo  =   $1459          ; per-ply move list pointer low
root_alloc_lo =  $145b          ; root alloc pointer low
ply_list_hi  =   $1463          ; per-ply move list pointer high
root_alloc_hi =  $1465          ; root alloc pointer high
board        =   $146e          ; board array (10x12 mailbox)
"""

# ── Replacement mappings ───────────────────────────────────────────────
# (hex_address, symbol_name, is_zp)
# For ZP: matches $XX (2 hex digits)
# For ABS: matches $XXXX (4 hex digits)

ZP_MAP = {
    '00': 'input_buf_idx',
    '05': 'str_ptr',
    '06': 'str_ptr+1',
    '07': 'cur_square',
    '08': 'target_sq',
    '09': 'castle_dir',
    '0a': 'hint_to_sq',
    '0b': 'move_from',
    '0c': 'move_to',
    '0d': 'piece_type',
    '0e': 'target_type',
    '0f': 'dir_index',
    '10': 'dir_count',
    '11': 'step_delta',
    '12': 'ray_flags',
    '13': 'cur_piece',
    '14': 'target_piece',
    '1c': 'book_status',
    '1d': 'legal_found',
    '1e': 'opening_bonus',
    '1f': 'joystick_flag',
    '61': 'score_lo',
    '62': 'score_hi',
    '63': 'best_exchange',
    '64': 'best_threat',
    '65': 'second_threat',
    '66': 'exchange_sq',
    '67': 'mobility_bal',
    '68': 'positional',
    '69': 'check_flag',
    '6a': 'material_bal',
    '6b': 'pawn_score',
    '6c': 'king_pos',
    '6d': 'king_pos+1',
    '6e': 'def_list_ptr',
    '6f': 'atk_list_ptr',
    '70': 'node_count_lo',
    '71': 'node_count_hi',
    '8b': 'move_list_ptr',
    '8c': 'move_list_ptr+1',
    '8d': 'move_index',
    '8e': 'alloc_ptr',
    '8f': 'alloc_ptr+1',
    '9c': 'book_code',
    '9f': 'prev_best',
    'a3': 'screen_ptr',
    'a4': 'screen_ptr+1',
    'a5': 'gfx_index',
    'a6': 'gfx_index+1',
    'a7': 'piece_stripped',
    'a8': 'flash_count',
    'a9': 'square_color',
    'aa': 'piece_byte',
    'ab': 'file_col',
    'ac': 'rank_row',
    'ad': 'dest_file',
    'ae': 'dest_rank',
    'b4': 'prev_hint_to',
    'b5': 'ply2_from',
    'b6': 'ply2_to',
    'f7': 'color_ptr',
    'f8': 'color_ptr+1',
    'f9': 'display_pos',
}

# Absolute addresses: exact address -> symbol or (base, offset)
ABS_BASES = {
    0x0200: 'input_buf',
    0x033c: 'notation_buf',
    0x1000: 'pv_buffer',
    0x1001: 'move_list',
    0x12fe: 'move_history',
    0x1319: 'exch_packed',
    0x1327: 'capture_stk',
    0x1328: 'captured',
    0x1331: 'flags_stk',
    0x1332: 'move_flags',
    0x133b: 'ply_idx_stk',
    0x1346: 'exch_squares',
    0x13c6: 'exch_sources',
    0x1445: 'killer_from',
    0x144f: 'killer_to',
    0x1459: 'ply_list_lo',
    0x145b: 'root_alloc_lo',
    0x1463: 'ply_list_hi',
    0x1465: 'root_alloc_hi',
    0x146e: 'board',
}

# Build a reverse lookup: for any absolute addr, find best base+offset
def resolve_abs(addr):
    """Given an absolute address, return symbolic name or base+offset."""
    if addr in ABS_BASES:
        return ABS_BASES[addr]
    # Find the closest base that's <= addr
    best_base = None
    best_offset = None
    for base_addr, base_name in sorted(ABS_BASES.items()):
        if base_addr <= addr:
            offset = addr - base_addr
            if offset <= 32:  # only use offsets up to 32
                if best_base is None or base_addr > best_base:
                    best_base = base_addr
                    best_offset = offset
    if best_base is not None and best_offset > 0:
        name = ABS_BASES[best_base]
        return f"{name}+{best_offset}"
    # Check if addr is 1 below a base (negative offset)
    for base_addr, base_name in ABS_BASES.items():
        if addr == base_addr - 1:
            return f"{base_name}-1"
    return None

# 6502 mnemonics that have operands (for matching instruction lines)
MNEMONICS = set("""
    lda ldx ldy sta stx sty
    adc sbc cmp cpx cpy
    and ora eor bit
    inc dec asl lsr rol ror
    jsr jmp
    bne beq bpl bmi bcc bcs bvs bvc
""".split())

# Directives to skip (data, not code)
SKIP_DIRECTIVES = {'.byte', '.word', '.res', '.asciiz', '.ascii', '.dbyt',
                   '.repeat', '.endrep', '.macro', '.endmacro', '.if',
                   '.elseif', '.else', '.endif', '.include', '.error',
                   '.define', '.setcpu'}

def is_instruction_line(line_before_comment):
    """Check if this line contains a 6502 instruction (not a directive or data)."""
    stripped = line_before_comment.strip()
    # Remove label if present
    if ':' in stripped:
        stripped = stripped[stripped.index(':') + 1:].strip()
    # Get first word
    parts = stripped.split()
    if not parts:
        return False
    mnemonic = parts[0].lower()
    if mnemonic in SKIP_DIRECTIVES:
        return False
    return mnemonic in MNEMONICS

def replace_in_operand(operand, full_line):
    """Replace magic addresses in an instruction operand."""
    result = operand

    # Replace absolute addresses (4 hex digits) - do these FIRST
    # Match $XXXX not preceded by # and not part of a longer hex number
    def abs_replacer(m):
        prefix = m.group(1)  # could be '(' or empty
        addr_hex = m.group(2)
        suffix = m.group(3)  # could be ',x', ',y', ')', etc.
        addr = int(addr_hex, 16)

        # Don't replace ROM/hardware addresses
        if addr >= 0x9000:
            return m.group(0)
        # Don't replace screen/color RAM pokes (display-only)
        if 0x1d00 <= addr <= 0x1fff or 0x9400 <= addr <= 0x97ff:
            return m.group(0)

        name = resolve_abs(addr)
        if name:
            return f"{prefix}{name}{suffix}"
        return m.group(0)

    # Match: optional '(' + '$' + 4 hex digits + optional suffix
    # Negative lookbehind for '#' (immediate mode)
    result = re.sub(
        r'(\(?)\$([0-9a-f]{4})([),]?)',
        abs_replacer,
        result,
        flags=re.IGNORECASE
    )

    # Replace zero-page addresses (1-2 hex digits)
    def zp_replacer(m):
        prefix = m.group(1)
        addr_hex = m.group(2).lower()
        suffix = m.group(3)

        if addr_hex in ZP_MAP:
            return f"{prefix}{ZP_MAP[addr_hex]}{suffix}"
        return m.group(0)

    # Match: optional '(' + '$' + 1-2 hex digits + NOT followed by more hex
    # Negative lookbehind for '#' and for another hex digit
    result = re.sub(
        r'(\(?)\$([0-9a-fA-F]{2})(?![0-9a-fA-F])([),]?)',
        zp_replacer,
        result
    )

    return result

def process_line(line):
    """Process a single line, replacing magic addresses in instruction operands."""
    # Split into code and comment
    comment_idx = line.find(';')
    if comment_idx >= 0:
        code_part = line[:comment_idx]
        comment_part = line[comment_idx:]
    else:
        code_part = line
        comment_part = ''

    # Skip if not an instruction line
    if not is_instruction_line(code_part):
        return line

    # Find the operand portion: after the mnemonic
    stripped = code_part.strip()
    # Remove label
    label_part = ''
    work = stripped
    if ':' in work:
        colon_pos = work.index(':')
        label_part = work[:colon_pos + 1]
        work = work[colon_pos + 1:].strip()

    # Split into mnemonic and operand
    parts = work.split(None, 1)
    if len(parts) < 2:
        return line  # no operand (e.g., rts, pha)

    mnemonic = parts[0]
    operand = parts[1]

    # Don't replace immediate operands (starts with #)
    if operand.startswith('#'):
        # But the # value might contain an address reference like #<board or #>board
        # For now, skip all immediates
        return line

    # Do the replacement in the operand
    new_operand = replace_in_operand(operand, line)

    if new_operand == operand:
        return line  # no change

    # Reconstruct the line preserving original formatting
    # Find where the operand starts in the original code_part
    # Strategy: find the mnemonic in code_part, then find the operand after it
    mnem_pattern = re.escape(mnemonic)
    mnem_match = re.search(r'\b' + mnem_pattern + r'\s+', code_part, re.IGNORECASE)
    if not mnem_match:
        return line

    operand_start = mnem_match.end()
    # Find where operand ends (before trailing spaces or comment)
    operand_in_code = code_part[operand_start:].rstrip()

    new_code = code_part[:operand_start] + new_operand
    # Pad to maintain comment alignment if there was a comment
    if comment_part:
        # Try to keep comment at same position
        orig_len = len(code_part.rstrip())
        new_len = len(new_code.rstrip())
        if orig_len > new_len:
            new_code = new_code.rstrip() + ' ' * (orig_len - new_len)
        new_code = new_code.rstrip()  # remove trailing spaces, we'll add padding

    result = new_code + comment_part
    return result.rstrip()

def main():
    filepath = 'SargonII.S'
    with open(filepath, 'r') as f:
        lines = f.readlines()

    # Find where to insert new equates (after existing equates, before code)
    # Insert after the opening_ptr line and before the system addresses
    insert_after = None
    for i, line in enumerate(lines):
        if 'opening_ptr' in line and '=' in line:
            insert_after = i
            break

    if insert_after is None:
        print("ERROR: Could not find insertion point for equates")
        sys.exit(1)

    # Insert new equates
    new_lines = lines[:insert_after + 1]
    new_lines.append('\n')
    for eq_line in NEW_EQUATES.strip().split('\n'):
        new_lines.append(eq_line + '\n')
    new_lines.append('\n')
    new_lines.extend(lines[insert_after + 1:])

    # Now process all lines for replacements
    processed = []
    for line in new_lines:
        processed.append(process_line(line.rstrip('\n')) + '\n')

    with open(filepath, 'w') as f:
        f.writelines(processed)

    # Count replacements
    orig_text = ''.join(lines)
    new_text = ''.join(processed)
    # Count remaining bare hex addresses in instruction operands
    # (rough estimate)
    print(f"Done. File updated.")

if __name__ == '__main__':
    main()
