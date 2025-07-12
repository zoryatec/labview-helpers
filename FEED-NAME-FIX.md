# Feed Name Preservation Fix

## Issue Description

When running `apply-nipksnapshot`, feeds were being added with malformed names instead of their intended names. For example:

**Expected Names:**
- `ni-labview-2024-core-x86-en-2024 Q3-released`
- `ni-labview-2024-core-x86-en-2024 Q3-released-critical`
- `ni-daqmx-2024 Q3-released`

**Actual Malformed Names:**
- `downloadnicomsupportnipkgproductsni-lni-labview-2024-x86243released`
- `downloadnicomsupportnipkgproductsni-lni-labview-2024-x86243released-critical`
- `downloadnicomsupportnipkgproductsni-dni-daqmx245released`

This caused the compliance check to report 28 issues with missing and extra feeds.

## Root Cause

The issue was in two functions in `NipkgHelper.psm1`:

1. **Apply-NipkgSnapshot** (line ~1970): Called `nipkg feed-add "$uri"` without specifying the `--name` parameter
2. **Add-FeedDirectories** (line ~88): Called `nipkg feed-add "$dir"` without specifying the `--name` parameter

When NIPKG adds a feed without an explicit name, it auto-generates one from the URI, which resulted in the malformed names.

## Fix Applied

Changed the feed-add commands to include the `--name` parameter:

### Before:
```powershell
& $NipkgCmdPath feed-add "$($feed.uri)"
& $NipkgCmdPath feed-add "$($dir.FullName)"
```

### After:
```powershell
& $NipkgCmdPath feed-add "$($feed.uri)" --name="$($feed.name)"
& $NipkgCmdPath feed-add "$($dir.FullName)" --name="$($dir.Name)"
```

## Files Modified

1. `c:\Projects\_Repos\labview-helpers\LabViewHelpers\NipkgHelper.psm1`
2. `c:\Projects\_Repos\zt-images\images\aib\win-25-labview-2024-q3\customization\zoryatec\labview-helpers\NipkgHelper.psm1`
3. `c:\Projects\_Repos\zt-images\images\aib\win-25-labview-2025-q1-community\customization\zoryatec\labview-helpers\NipkgHelper.psm1`

## How to Test the Fix

1. **Clean up existing malformed feeds** (optional but recommended):
   ```powershell
   # Remove all existing feeds and start fresh
   Import-NipkgSnapshotFromJson "your-snapshot.json" | Apply-NipkgSnapshot -RemoveExistingFeeds
   ```

2. **Or remove specific malformed feeds**:
   ```powershell
   nipkg feed-remove "downloadnicomsupportnipkgproductsni-lni-labview-2024-x86243released"
   nipkg feed-remove "downloadnicomsupportnipkgproductsni-lni-labview-2024-x86243released-critical"
   # ... etc for all malformed feeds
   ```

3. **Run apply-nipksnapshot again**:
   ```powershell
   Import-NipkgSnapshotFromJson "your-snapshot.json" | Apply-NipkgSnapshot
   ```

4. **Verify the fix with compliance check**:
   ```powershell
   Test-NipkgSnapshotCompliance -SnapshotPath "your-snapshot.json"
   ```

## Expected Results After Fix

- Feeds should be added with their correct names as specified in the snapshot
- The compliance check should show `Feeds: COMPLIANT` instead of `NON-COMPLIANT`
- No more warnings about missing/extra feeds due to name mismatches

## Prevention

This fix ensures that:
- Feed names from snapshots are preserved exactly as intended
- Directory-based feeds use the directory name as the feed name
- The NIPKG feed naming is consistent and predictable

## Testing

A test script has been created at `test/manual/test-feed-name-fix.ps1` to verify the fix works correctly.
