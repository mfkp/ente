import React from 'react';
import { ExportProgress } from 'types/export';
import {
    Box,
    Button,
    DialogActions,
    DialogContent,
    styled,
} from '@mui/material';
import { ExportStage } from 'constants/export';
import VerticallyCentered, { FlexWrapper } from './Container';
import { ProgressBar } from 'react-bootstrap';
import { t } from 'i18next';
import { Trans } from 'react-i18next';

export const ComfySpan = styled('span')`
    padding: 0 0.5rem;
    word-spacing: 1rem;
    color: #ddd;
`;

interface Props {
    exportStage: ExportStage;
    exportProgress: ExportProgress;
    stopExport: () => void;
    closeExportDialog: () => void;
}

export default function ExportInProgress(props: Props) {
    return (
        <>
            <DialogContent>
                <VerticallyCentered>
                    <Box mb={1.5}>
                        <Trans
                            i18nKey={'EXPORT_PROGRESS'}
                            components={{
                                a: <ComfySpan />,
                            }}
                            values={{
                                progress: props.exportProgress,
                            }}
                        />
                    </Box>
                    <FlexWrapper px={1}>
                        <ProgressBar
                            style={{ width: '100%' }}
                            now={Math.round(
                                (props.exportProgress.current * 100) /
                                    props.exportProgress.total
                            )}
                            animated
                            variant="upload-progress-bar"
                        />
                    </FlexWrapper>
                </VerticallyCentered>
            </DialogContent>
            <DialogActions>
                <Button
                    color="secondary"
                    size="large"
                    onClick={props.closeExportDialog}>
                    {t('CLOSE')}
                </Button>
                <Button size="large" color="danger" onClick={props.stopExport}>
                    {t('STOP_EXPORT')}
                </Button>
            </DialogActions>
        </>
    );
}
