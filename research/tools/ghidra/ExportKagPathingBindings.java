// Export focused evidence for the KAG AngelScript pathing/movement boundary.
// Raw output belongs on E: (or another ignored private analysis location).
// @category KAG Research

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.DataIterator;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.program.model.symbol.ReferenceManager;

import java.io.File;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class ExportKagPathingBindings extends GhidraScript {
    private static final String[] TARGET_DECLARATIONS = {
        "void SetPathTo(Vec2f endpoint, bool ignoreGravity)",
        "void SetPathTo(Vec2f endpoint, int search_style)",
        "void SetSuggestedKeys()",
        "CBrain::BrainState getState()",
        "int getPathSize()",
        "Vec2f getPathPositionAtIndex( int index )",
        "void EndPath()",
        "void setKeyPressed( keys key, bool pressed )",
        "bool isKeyPressed( keys key )",
        "Vec2f getPosition()",
        "Vec2f getOldPosition()",
        "Vec2f getVelocity()",
        "bool isOnGround()",
        "bool isOnWall()",
        "bool isOnLadder()",
        "bool rayCastSolid(Vec2f startPosWorldspace, Vec2f endPosWorldspace)",
        "bool isTileSolid(Vec2f posWorldspace)",
        "Tile getTile(Vec2f posWorldspace)",
        "bool getBlobsInBox( Vec2f upperleftWorldspace, Vec2f lowerrightWorldspace, CBlob@[]@ list )"
    };

    private static final int DISASSEMBLY_BEFORE = 24;
    private static final int DISASSEMBLY_AFTER = 8;
    private static final int DECOMPILE_CONTEXT_LINES = 18;

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length != 1) {
            throw new IllegalArgumentException("Expected one output directory argument");
        }

        File outputDirectory = new File(args[0]);
        if (!outputDirectory.isDirectory() && !outputDirectory.mkdirs()) {
            throw new IllegalStateException("Cannot create output directory: " + outputDirectory);
        }

        Listing listing = currentProgram.getListing();
        FunctionManager functions = currentProgram.getFunctionManager();
        ReferenceManager references = currentProgram.getReferenceManager();
        Map<String, List<Address>> matches = findTargetStrings(listing);
        Map<Address, Set<String>> declarationsByFunction = new LinkedHashMap<>();
        Map<String, List<Reference>> referencesByDeclaration = new LinkedHashMap<>();

        for (String declaration : TARGET_DECLARATIONS) {
            List<Reference> declarationReferences = new ArrayList<>();
            for (Address stringAddress : matches.get(declaration)) {
                ReferenceIterator iterator = references.getReferencesTo(stringAddress);
                while (iterator.hasNext()) {
                    Reference reference = iterator.next();
                    declarationReferences.add(reference);
                    Function function = functions.getFunctionContaining(reference.getFromAddress());
                    if (function != null) {
                        declarationsByFunction
                            .computeIfAbsent(function.getEntryPoint(), ignored -> new LinkedHashSet<>())
                            .add(declaration);
                    }
                }
            }
            declarationReferences.sort(Comparator.comparing(Reference::getFromAddress));
            referencesByDeclaration.put(declaration, declarationReferences);
        }

        File output = new File(outputDirectory, "kag_pathing_bindings.txt");
        try (PrintWriter writer = new PrintWriter(output, StandardCharsets.UTF_8)) {
            writer.println("KAG focused pathing/movement binding evidence");
            writer.println("generated_utc=" + Instant.now());
            writer.println("program=" + currentProgram.getName());
            writer.println("image_base=" + currentProgram.getImageBase());
            writer.println();

            DecompInterface decompiler = new DecompInterface();
            decompiler.toggleCCode(true);
            decompiler.toggleSyntaxTree(true);
            decompiler.setSimplificationStyle("decompile");
            if (!decompiler.openProgram(currentProgram)) {
                throw new IllegalStateException("Decompiler could not open current program");
            }

            try {
                Map<Address, String> decompiledByFunction = new LinkedHashMap<>();
                for (Address functionAddress : declarationsByFunction.keySet()) {
                    Function function = functions.getFunctionAt(functionAddress);
                    if (function == null) {
                        continue;
                    }
                    DecompileResults result = decompiler.decompileFunction(function, 180, monitor);
                    String c = result.decompileCompleted() && result.getDecompiledFunction() != null
                        ? result.getDecompiledFunction().getC()
                        : "DECOMPILE FAILED: " + result.getErrorMessage();
                    decompiledByFunction.put(functionAddress, c);
                }

                for (String declaration : TARGET_DECLARATIONS) {
                    writer.println("================================================================================");
                    writer.println("DECLARATION " + declaration);
                    writer.println("string_addresses=" + matches.get(declaration));
                    List<Reference> declarationReferences = referencesByDeclaration.get(declaration);
                    writer.println("xref_count=" + declarationReferences.size());

                    for (Reference reference : declarationReferences) {
                        Address from = reference.getFromAddress();
                        Function function = functions.getFunctionContaining(from);
                        writer.println("--------------------------------------------------------------------------------");
                        writer.println("xref_from=" + from);
                        writer.println("container=" + (function == null ? "<none>" :
                            function.getName() + " @ " + function.getEntryPoint()));
                        writeInstructionWindow(writer, listing, from);

                        if (function != null) {
                            writeDecompilerContext(writer,
                                decompiledByFunction.get(function.getEntryPoint()), declaration);
                        }
                    }
                    writer.println();
                }
            }
            finally {
                decompiler.dispose();
            }
        }

        println("KAG pathing binding evidence exported to " + output.getAbsolutePath());
    }

    private Map<String, List<Address>> findTargetStrings(Listing listing) {
        Map<String, List<Address>> matches = new LinkedHashMap<>();
        for (String declaration : TARGET_DECLARATIONS) {
            matches.put(declaration, new ArrayList<>());
        }

        DataIterator iterator = listing.getDefinedData(true);
        while (iterator.hasNext() && !monitor.isCancelled()) {
            Data data = iterator.next();
            Object value = data.getValue();
            if (!(value instanceof String)) {
                continue;
            }
            String text = (String)value;
            for (String declaration : TARGET_DECLARATIONS) {
                if (text.equals(declaration)) {
                    matches.get(declaration).add(data.getAddress());
                }
            }
        }
        return matches;
    }

    private void writeInstructionWindow(PrintWriter writer, Listing listing, Address center) {
        List<Instruction> before = new ArrayList<>();
        Instruction instruction = listing.getInstructionAt(center);
        if (instruction == null) {
            instruction = listing.getInstructionContaining(center);
        }
        if (instruction == null) {
            writer.println("instruction_window=<unavailable>");
            return;
        }

        Instruction cursor = instruction;
        for (int i = 0; i < DISASSEMBLY_BEFORE; ++i) {
            cursor = cursor.getPrevious();
            if (cursor == null) {
                break;
            }
            before.add(0, cursor);
        }

        writer.println("instruction_window:");
        for (Instruction prior : before) {
            writer.println("  " + prior.getAddress() + "  " + prior);
        }
        writer.println("* " + instruction.getAddress() + "  " + instruction);
        cursor = instruction;
        for (int i = 0; i < DISASSEMBLY_AFTER; ++i) {
            cursor = cursor.getNext();
            if (cursor == null) {
                break;
            }
            writer.println("  " + cursor.getAddress() + "  " + cursor);
        }
    }

    private void writeDecompilerContext(PrintWriter writer, String c, String declaration) {
        if (c == null) {
            writer.println("decompiler_context=<unavailable>");
            return;
        }
        String[] lines = c.split("\\R", -1);
        int match = -1;
        for (int i = 0; i < lines.length; ++i) {
            if (lines[i].contains(declaration)) {
                match = i;
                break;
            }
        }
        if (match < 0) {
            writer.println("decompiler_context=<declaration not found in output>");
            return;
        }

        writer.println("decompiler_context:");
        int first = Math.max(0, match - DECOMPILE_CONTEXT_LINES);
        int last = Math.min(lines.length - 1, match + DECOMPILE_CONTEXT_LINES);
        for (int i = first; i <= last; ++i) {
            writer.println((i == match ? "* " : "  ") + lines[i]);
        }
    }
}
